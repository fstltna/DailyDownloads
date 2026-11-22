#!/usr/bin/perl

# This tool scans the entries in the jdownloads download log for files
# downloaded the previous day and emails a summary table.

use strict;
use warnings;
use DBI;
use Email::Valid;
use Number::Bytes::Human;
use POSIX qw(mktime strftime);

# No changes below here
my $VERSION    = "1.4.0";
my $DB_Owner   = "";
my $DB_Pswd    = "";
my $DB_Name    = "";
my $DB_Prefix  = "";
my $NotifyEmail = "";
my $CONF_FILE  = "$ENV{HOME}/.dailydownloads.ini";
my $FILEEDITOR = (defined $ENV{EDITOR} && $ENV{EDITOR} ne "") ? $ENV{EDITOR} : "vi";

my $hostname = `hostname`;
chomp($hostname);

# Get if they said a option
my $CMDOPTION = shift;

# Read in configuration options
if (! -f $CONF_FILE)
{
	my $DefaultConf = <<'END_MESSAGE';
DB_User	joomla
DB_Pswd	foobar
DB_DBName	joomla
DB_DBtblpfx	zzz_
NotifyEmail	some_address
END_MESSAGE
	open (my $FH, ">", $CONF_FILE) or die "Could not create config file '$CONF_FILE' $!";
	print $FH $DefaultConf;
	close($FH);
	system("$FILEEDITOR $CONF_FILE");
	exit 0;
}

open(my $CONF, "<", $CONF_FILE) || die("Unable to read config file '$CONF_FILE': $!");
while (<$CONF>)
{
	s/\r?\n$//;		# chomp, also handles CRLF line endings
	next if ($_ eq "");
	my ($FIELD_TYPE, $FIELD_VALUE) = split(/\t/, $_, 2);
	if (! defined($FIELD_VALUE))
	{
		print "No tab-separated value for config line '$_'\n";
		next;
	}
	if    ($FIELD_TYPE eq "DB_User")     { $DB_Owner    = $FIELD_VALUE; }
	elsif ($FIELD_TYPE eq "DB_Pswd")     { $DB_Pswd     = $FIELD_VALUE; }
	elsif ($FIELD_TYPE eq "DB_DBName")   { $DB_Name     = $FIELD_VALUE; }
	elsif ($FIELD_TYPE eq "DB_DBtblpfx") { $DB_Prefix   = $FIELD_VALUE; }
	elsif ($FIELD_TYPE eq "NotifyEmail") { $NotifyEmail = $FIELD_VALUE; }
}
close($CONF);

print("dailydownloads log parser ($VERSION)\n");
print("===========================================\n");

if (defined $CMDOPTION)
{
	if ($CMDOPTION ne "prefs")
	{
		print "Unknown command line option: '$CMDOPTION'\nOnly allowed option is 'prefs'\n";
		exit 1;
	}
	system("$FILEEDITOR $CONF_FILE");
	exit 0;
}

unless (Email::Valid->address($NotifyEmail))
{
	print("Invalid email address: '$NotifyEmail'\n");
	exit(1);
}

# Work out yesterday's date. mktime normalises "day 0" into the last day of
# the previous month (and Jan 0 into Dec 31 of last year). Using noon avoids
# daylight-saving edge cases.
my @now = localtime();
my $Yesterday = strftime("%Y-%m-%d",
	localtime(mktime(0, 0, 12, $now[3] - 1, $now[4], $now[5])));
print "Looking for downloads on $Yesterday\n";

### The database handle
my $dbh = DBI->connect("DBI:mysql:database=$DB_Name;host=localhost",
                       $DB_Owner, $DB_Pswd, { RaiseError => 0, PrintError => 1 })
	or die "Can't connect to database: $DBI::errstr\n";

my $DB_Table = $DB_Prefix . "jdownloads_logs";

# Let MySQL do the date filtering instead of pulling the whole log table.
my $sth = $dbh->prepare(
	"SELECT log_file_size, log_file_name, log_title FROM $DB_Table " .
	"WHERE DATE(log_datetime) = ?")
	or die $dbh->errstr;
$sth->execute($Yesterday) or die $dbh->errstr;

my %SawFiles;
my %SawSize;
my $NumSeen = 0;
my $human = Number::Bytes::Human->new(bs => 1000, round_style => 'round', precision => 2);

while (my $row = $sth->fetchrow_hashref)
{
	my $FileTitle = $row->{'log_title'};
	next if (! defined($FileTitle) || $FileTitle eq "");

	my $FileName = $row->{'log_file_name'} // "(unknown)";
	my $FileSize = $row->{'log_file_size'} // 0;

	$SawFiles{$FileName} += 1;
	$NumSeen += 1;

	if ($FileSize !~ /^\d+(\.\d+)?$/)
	{
		# Not a plain number - keep whatever jDownloads stored
	}
	elsif ($FileSize == 0)
	{
		$FileSize = "< 1kb";
	}
	else
	{
		$FileSize = $human->format($FileSize * 1000);
	}
	$SawSize{$FileName} = $FileSize;
}
$sth->finish;
$dbh->disconnect;

if ($NumSeen == 0)
{
	# Didnt see any downloads
	print "No downloads previous day\n";
	exit 0;
}

sub html_escape
{
	my $s = shift;
	$s =~ s/&/&amp;/g;
	$s =~ s/</&lt;/g;
	$s =~ s/>/&gt;/g;
	$s =~ s/"/&quot;/g;
	return $s;
}

# Build the HTML body in memory: most-downloaded first, then by name.
my $rows = "";
for my $MyFile (sort { $SawFiles{$b} <=> $SawFiles{$a} || lc($a) cmp lc($b) } keys %SawFiles)
{
	print "The count of '$MyFile' is $SawFiles{$MyFile}\n";
	$rows .= "<tr><td>$SawFiles{$MyFile}</td><td>" . html_escape($MyFile) .
	         "</td><td>" . html_escape($SawSize{$MyFile}) . "</td></tr>\n";
}

my $message = <<"END";
<html>
<head>
<title>Latest Files</title>
</head>
<body>
<h3>Downloads on $Yesterday</h3>
<table border=2>
<tr><th>Count</th><th>Filename</th><th>File Size</th></tr>
$rows</table>
</body>
</html>
END

# Create the mail
open(my $MAIL, "|-", "/usr/sbin/sendmail -t") or die "Can't run sendmail: $!";
print $MAIL "To: $NotifyEmail\n";
print $MAIL "From: noreply\@$hostname\n";
print $MAIL "Subject: $hostname: $NumSeen files downloaded on $Yesterday\n";
print $MAIL "MIME-Version: 1.0\n";
print $MAIL "Content-Type: text/html; charset=UTF-8\n\n";
print $MAIL $message;
close($MAIL) or warn "sendmail exited with status $?\n";

exit(0);
