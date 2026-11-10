#!/usr/bin/env bash
set -euo pipefail

mode="${1:-normal}"
owner="markmrcela-struxis"
timestamp="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

case "$mode" in
  normal|failure|recovery) ;;
  *) echo "Unsupported test mode" >&2; exit 2 ;;
esac

check_url() {
  local url="$1"
  local output status
  output="$(mktemp)"
  if status="$(curl --silent --show-error --location --max-time 15 --retry 2 --retry-delay 2 --output "$output" --write-out '%{http_code}' "$url")"; then
    if [[ "$status" == "200" && -s "$output" ]]; then
      printf '%s: HTTP %s with nonempty body\n' "$url" "$status"
      rm -f "$output"
      return 0
    fi
    printf '%s: unexpected HTTP %s or empty body\n' "$url" "$status" >&2
  else
    printf '%s: request failed, final HTTP %s\n' "$url" "${status:-none}" >&2
  fi
  rm -f "$output"
  return 1
}

failed=0
check_url 'https://struxis.app/' || failed=1
check_url 'https://struxis.app/early-access' || failed=1

if [[ "$mode" == "failure" ]]; then
  echo 'Controlled test: treating healthy responses as a simulated failure.'
  failed=1
elif [[ "$mode" == "recovery" && "$failed" -ne 0 ]]; then
  echo 'Cannot simulate recovery while a live probe fails.' >&2
  exit 1
fi

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "Dry run: mode=$mode failed=$failed checked=$timestamp"
  exit "$failed"
fi

if [[ "$mode" == "normal" ]]; then
  label='uptime-incident'
  title='STRUXIS website availability incident'
else
  label='uptime-test'
  title='TEST: STRUXIS website availability notification'
fi

issue="$(gh issue list --repo "$GH_REPO" --state open --label "$label" --json number --jq '.[0].number // empty')"
if [[ "$failed" -ne 0 ]]; then
  if [[ -z "$issue" ]]; then
    body="$(mktemp)"
    {
      printf '@%s Website availability check failed at %s.\n\n' "$owner" "$timestamp"
      printf 'Checked `https://struxis.app/` and `https://struxis.app/early-access` with external HTTP GET requests.\n'
      if [[ "$mode" == "failure" ]]; then
        printf '\n**Controlled notification test.** The production site was not made unavailable.\n'
      else
        printf '\nReview the workflow log for the exact response. The monitor will close this issue after both URLs recover.\n'
      fi
    } > "$body"
    gh issue create --repo "$GH_REPO" --title "$title" --label "$label" --assignee "$owner" --body-file "$body"
    rm -f "$body"
  else
    echo "Existing open $label issue #$issue; suppressing duplicate issue."
  fi
  exit 1
fi

if [[ -n "$issue" ]]; then
  note='The public URLs have recovered.'
  if [[ "$mode" == "recovery" ]]; then note='Controlled test recovery; no outage occurred.'; fi
  gh issue comment "$issue" --repo "$GH_REPO" --body "@$owner Both public URLs returned HTTP 200 with nonempty bodies at $timestamp. $note"
  gh issue close "$issue" --repo "$GH_REPO" --reason completed
  echo "Recovered and closed issue #$issue."
else
  echo "Healthy: both public URLs returned HTTP 200 at $timestamp."
fi
