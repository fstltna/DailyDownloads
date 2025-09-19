#!/usr/bin/perl

# This tool scans all the entries in the jddownloads database to set
# icon to the type for that file

use strict;
use warnings;
use DBI;
use DBD::mysql;


# No changes below here
my $CurTitle="";
my $CurAlias="";
my $CurFilePic="";
my $CurFileName="";
my $CurId=0;
my $CurStatus="";
my $timeout=5;
my $VERSION="1.2";
my $DB_Owner="";
my $DB_Pswd="";
my $DB_Name="";
my $DB_Prefix="";
my $DB_Table="";
my $dbh;
my $CONF_FILE="$ENV{HOME}/.scanjdsettings.ini";
my $CurNotify="";
my $CurName="";
my $email="";
my $IconDir="/var/www/html/images/jdownloads/fileimages/flat_1/";
my $UnknownType = "unknown";
my $FILEEDITOR = $ENV{EDITOR};

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
DB_User root
DB_Pswd foobar
DB_DBName       joomla
DB_DBtblpfx     zzz_
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
}
close(CONF);

# Checks the file type
sub CheckFileType
{
	my $DotPos = rindex($CurFileName, ".");
	if ($DotPos == 0)
	{
		print "Did not see a dot in $CurFileName\n";
		return;
	}
	my $FileType = substr($CurFileName, $DotPos + 1);
#	print "File Type = $FileType\n";
#	print "Saw $CurFileName\n";
	if (-f "$IconDir/$FileType.png")
	{
		# Saw this file type
#		print "Saw file type\n";
	}
	else
	{
		# Didn't see this file type
#		print "Did not see file type - setting to $UnknownType\n";
		$FileType = $UnknownType;
	}
	# Check if the file type has changed
	if ($CurFilePic ne "$FileType.png")
	{
print "CurFileName = '$CurFileName'\n";
print "\tCurFilePic = '$CurFilePic'\n";
print "\tFileType = '$FileType.png'\n";
		# Extensions differ, update file record
		$CurFilePic = "$FileType.png";
#next;
		$dbh->do("UPDATE $DB_Table SET file_pic = ? WHERE id = ?",
			undef,
			$CurFilePic,
			$CurId);
	}
}

print("jddownloads file type updater ($VERSION)\n");
print("===========================================\n");

if (defined $CMDOPTION)
{
        if ($CMDOPTION ne "prefs")
        {
                print "Unknown command line option: '$CMDOPTION'\nOnly allowed option is 'prefs'\n";
                exit 0;
        }
	system("$FILEEDITOR $CONF_FILE");
	exit 0;
}

### The database handle
$dbh = DBI->connect ("DBI:mysql:database=$DB_Name:host=localhost",
                           $DB_Owner,
                           $DB_Pswd) 
                           or die "Can't connect to database: $DBI::errstr\n";

$DB_Table = $DB_Prefix . "jdownloads_files";

### The statement handle
my $sth = $dbh->prepare("SELECT id, title, alias, file_pic, url_download FROM $DB_Table");

$sth->execute or die $dbh->errstr;

my $rows_found = $sth->rows;

while (my $row = $sth->fetchrow_hashref)
{
	$CurId = $row->{'id'};
	$CurTitle = $row->{'title'};
	$CurAlias = $row->{'alias'};
	$CurFilePic = $row->{'file_pic'};
	$CurFileName = $row->{'url_download'};
	# print "Saw $CurTitle\n";
	if ($CurFileName ne "")
	{
		CheckFileType();
	}
}
exit(0);
