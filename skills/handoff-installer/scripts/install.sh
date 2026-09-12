#!/bin/sh
# Old repository install commands must not silently mutate global configuration.
set -eu
printf '%s\n' 'Repository protocol installation has been retired.' >&2
printf '%s\n' 'Enable the global runtime explicitly with scripts/setup.py enable --agents <clients>.' >&2
printf '%s\n' 'For an old repository, use scripts/migrate.py status|migrate <repo>.' >&2
exit 2
