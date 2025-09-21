#!/usr/bin/perl

# This tool scans the entries in the jddownloads download log for files
# downloaded the previous day

use strict;
use warnings;
use DBI;
use DBD::mysql;
#use Email::MIME;
use Email::Valid;
#use Email::Simple;
#use Email::Simple::Creator;
#use Email::Sender::Simple qw(sendmail);
use Number::Bytes::Human qw(format_bytes parse_bytes);

# No changes below here
my $CurId=0;
my $VERSION="1.1.1";
my $DB_Owner="";
my $DB_Pswd="";
my $DB_Name="";
my $DB_Prefix="";
my $DB_Table="";
my $dbh;
my $CONF_FILE="$ENV{HOME}/.dailydownloads.ini";
my $NotifyEmail="";
my $FILEEDITOR = $ENV{EDITOR};
my $TempFile = "/tmp/dailydown_temp-$$.txt";
my $SortedFile = "/tmp/dailydown_sorted-$$.txt";
my $EmailMessage = "/tmp/email-$$.txt";
if (-f $TempFile)
{
	print "Temp file alreadyt exists\n";
	exit 1;
}
my %SawFiles;
my %SawSize;
my $NumSeen = 0;
my $hostname = `hostname`;
chomp($hostname);
my $EmailBody = "Downloads\t- File Name\t- File Size\n================================================\n";

if (! defined($FILEEDITOR))
{
        $FILEEDITOR = "vi";
}
elsif ($FILEEDITOR eq "")
{
        $FILEEDITOR = "vi";
}

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
        print $FH "$DefaultConf\n";
	close($FH);
	system("$FILEEDITOR $CONF_FILE");
	exit 0;
}

open(CONF, "<$CONF_FILE") || die("Unable to read config file '$CONF_FILE'");
while(<CONF>)
{
	chop;
	if ($_ eq "")
	{
		next;
	}
	my ($FIELD_TYPE, $FIELD_VALUE) = split (/	/, $_);
	#print("Type is $FIELD_TYPE\n");
	if (! defined($FIELD_TYPE))
	{
		# Field type not defined
		print "Field type not defined for '$_'\n";
		next;
	}
	if ($FIELD_TYPE eq "DB_User")
	{
		$DB_Owner = $FIELD_VALUE;
	}
	elsif ($FIELD_TYPE eq "DB_Pswd")
	{
		$DB_Pswd = $FIELD_VALUE;
	}
	elsif ($FIELD_TYPE eq "DB_DBName")
	{
		$DB_Name = $FIELD_VALUE;
	}
	elsif ($FIELD_TYPE eq "DB_DBtblpfx")
	{
		$DB_Prefix = $FIELD_VALUE;
	}
	elsif ($FIELD_TYPE eq "NotifyEmail")
	{
		$NotifyEmail = $FIELD_VALUE;
	}
}
close(CONF);

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
	exit (1);
}

### The database handle
$dbh = DBI->connect ("DBI:mysql:database=$DB_Name:host=localhost",
                           $DB_Owner,
                           $DB_Pswd) 
                           or die "Can't connect to database: $DBI::errstr\n";

$DB_Table = $DB_Prefix . "jdownloads_logs";

### The statement handle
my $sth = $dbh->prepare("SELECT id, log_file_size, log_file_name, log_title, log_datetime FROM $DB_Table");

$sth->execute or die $dbh->errstr;

my $rows_found = $sth->rows;

my ($sec,$min,$hour,$curday,$curmon,$curyear,$wday,$yday,$isdst) = localtime();

$curyear = 1900 + $curyear;
$curmon = 1 + $curmon;
$curday = $curday -= 1;	# Set previous day

#print "curyear '$curyear'\n";
#print "curmon '$curmon'\n";
#print "curday '$curday'\n";
open (my $TempFH, '>', $TempFile) || die ($!);

while (my $row = $sth->fetchrow_hashref)
{
	$CurId = $row->{'id'};
	my $FileSize = $row->{'log_file_size'};
	my $FileName = $row->{'log_file_name'};
	my $FileTitle = $row->{'log_title'};
	my $FileDateTime = $row->{'log_datetime'};
	if ($FileTitle ne "")
	{
		#print "Saw '$FileTitle'\n";
		#print "\tSaw '$FileName'\n";
		# print "\tSaw '$FileDateTime'\n";
		my @DateString = split(/ /, $FileDateTime);
		# print "\tDateOnly = '$DateString[0]'\n";
		my ($FileYear, $FileMonth, $FileDay) = split(/-/, $DateString[0]);
		# print "Year = $FileYear\n";
		# print "Month = $FileMonth\n";
		# print "Day = $FileDay\n";
		if ($curyear != $FileYear)
		{
			#print "Year '$curyear' Different\n";
			next;
		}
		elsif ($curmon != $FileMonth)
		{
			# print "Month '$curmon' Different\n";
			next;
		}
		elsif ($curday != $FileDay)
		{
			#print "Day '$curday' Different\n";
			next;
		}
		$SawFiles{$FileName} += 1;
		$NumSeen += 1;
		my $human = Number::Bytes::Human->new(bs => 1000, round_style => 'round', precision => 2);
		$FileSize = $human->format($FileSize);
		$SawSize{$FileName} = $FileSize;
	}
}
for my $MyFile (keys %SawFiles)
{
	print "The count of '$MyFile' is $SawFiles{$MyFile}\n";
	#print "The size '$MyFile' is $SawSize{$MyFile}\n";
	#print ($TempFH "$SawFiles{$MyFile} - $FileName - $FileTitle\n");
	print ($TempFH "$SawFiles{$MyFile} - $MyFile - $SawSize{$MyFile}\n");
	#print "File from yesterday: $FileName\n";
}
close($TempFH);

# Sort the temp file
system("sort -frn $TempFile > $SortedFile");
if (-f $TempFile)
{
	unlink ($TempFile);
}

if (! -f $SortedFile)
{
	print "Sorted file not found - aborting\n";
	exit 1;
}

open (my $SortedFH, '<', $SortedFile) || die ($!);
open (my $EmailFH, '>', $EmailMessage) || die ($!);
print ($EmailFH "Downloads - File Name - File Size\n");
print ($EmailFH "================================================\n");
close ($EmailFH);
system("cat $SortedFile >> $EmailMessage");
unlink($SortedFile);

if ($NumSeen == 0)
{
	# Didnt see any downloads
	print "No downloads previous day\n";
	exit 0;
}

# Create the mail
open(MAIL, "|/usr/sbin/sendmail -t");

# Email Header
print MAIL "To: $NotifyEmail\n";
print MAIL "From: noreply\@$hostname\n";
print MAIL "Subject: $hostname: $NumSeen files downloaded\n\n";

# Email Body
my $message = `cat $EmailMessage`;
print MAIL $message;
close(MAIL);

unlink($EmailMessage);
exit(0);
