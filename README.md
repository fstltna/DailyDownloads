# scan_downloads (1.2.0) & scan_phodownloads (1.0.0)
Scans the files downloaded using jdownloads or phocadownloads on the previous day and emails the results to the specified address.

***

1. If you don't know what your table prefix is you can use the following commands to see what it is. The prefix MUST end with a "_".

        grep dbprefix /var/www/html/configuration.php

2. Run this script to install the dependencies:

        ./installdeps

3. For jdownloads processing run this script and the first time it will ask you to configure the tool.

        ./scan_downloads.pl

	If you need to change the settings run:

        ./scan_downloads.pl prefs

4. For phocadownloads processing run this script and the first time it will ask you to configure the tool.

        ./scan_phodownloads.pl

	If you need to change the settings run:

        ./scan_phodownloads.pl prefs

5. That should be enough, it should be workable now.

6. Add this to your crontab for jdownloads:

        1 0 * * * /root/DailyDownloads/scan_downloads.pl > /dev/null 2>&1

    or for phocadownloads:

        1 0 * * * /root/DailyDownloads/scan_phodownloads.pl > /dev/null 2>&1

