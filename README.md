# STRUXIS public website availability check

This independent GitHub Actions check reads the public STRUXIS homepage and the interest-only Early Access page every five minutes. It does not submit the form, access customer records, deploy the site, or change Search Console.

On failure, the workflow opens one incident issue and assigns the STRUXIS website owner. On recovery, it comments on and closes that issue. A separate test mode exercises the same notification path without causing a real outage. The workflow uses GitHub's built-in short-lived token; no stored secret or paid service is required.

The existing 9 AM Eastern Search Console and site-health watch remains unchanged. GitHub scheduled runs may be delayed or dropped under load, so this check is an operational alert, not an uptime SLA. A monthly monitor-repository commit keeps public-repository scheduling from being disabled for inactivity.
