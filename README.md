# jddownloads_file_types (1.0.0)
Scans the files downloaded using jdownloads and emails the results to the specified address.

***

1. If you don't know what your table prefix is you can use the following commands to see what it is. The prefix MUST end with a "_".

        grep dbprefix /var/www/html/configuration.php

2. Run this script to install the dependencies:

	./installdeps

3. Run this script and the first time it will ask you to configure the tool.

	./scan_downloads.pl

	If you need to change the settings run:

	./scan_downloads.pl prefs

4. That should be enough, it should be workable now.

