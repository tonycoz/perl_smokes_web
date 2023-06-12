# perl.develop-help.com

This is the new implementation of perl.develop-help.com, an aggregator
of smoke or community provided build and test reports for the perl
project.

The original front-end code was a fairly horrible mix of controller
and presentation in HTML::Mason templates.

The front-end code is largely new, based on Mojolicious, while the
back end code is still mostly the old code, but pulls the
configuration from the config file instead of hardcoded database
connection details.  Yay progress.

There are some APIs provided which are mostly intended for internal
use.

If you want an up to date snapshot of the database to test against
open an issue.

I'll be continuing to port the back end code to the new project.