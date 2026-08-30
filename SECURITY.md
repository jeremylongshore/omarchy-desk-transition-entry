# Security Policy

Report suspected vulnerabilities privately through GitHub's security advisory
feature for this repository. Do not include sensitive host or display metadata
in a public issue.

Desk Transition reads only the local `hyprctl -j monitors` inventory. The
producer is limited to three seconds and 65,536 bytes; output is capped to eight
validated connector names and bounded dimensions. The plugin stays offline,
uses no credentials, and never disables an output. Scene and focus actions
re-read inventory and pass a validated current connector name as an argument.

Marketplace verification confirms an exact snapshot and automated baseline;
it is not a security audit, certification, warranty, or endorsement.
