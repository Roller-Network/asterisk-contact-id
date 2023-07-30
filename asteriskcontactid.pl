#!/usr/bin/perl
#
# asteriskcontactid.pl
# https://github.com/WillCodeForCats/asterisk-contact-id
#
# A Contact ID handler for Asterisk's AlarmReceiver() application.
# https://wiki.asterisk.org
#
# Uses rcell-smsclient for direct SMS notifications
# https://github.com/WillCodeForCats/rcell-smsclient
#
#

use strict;
use IO::Dir;
use DBI;
use DateTime::Format::Strptime;
use DateTime::Format::MySQL;
use MIME::Lite;

my $spoolDir = '/var/spool/asterisk/alarmreceiver';
my $dbi = "DBI:mysql:host=localhost;database=asterisk";
my $dbuIser = "asterisk";
my $dbiPassword = "qwertyuiop123456789";

my $emailFrom = 'alarmreceiver@example.com';
my $timezone = 'America/Los_Angeles';

# account names
my %accts = (
        1111 => "Account 1111",
        2222 => "Another Account 2222",
        3333 => "Third Account 3333",
);

# who to notify per account
# 10-digit cell number for SMS or email address only
my %notify = (
        1111 => [
                    'user@example.com', '5555551234',
                ],
        2222 => [
                    'user@example.com', '5555551234',
                    'user2@example.com', '5555551234',
                ],
        3333 => [
                    'user@example.com', '5555551234',
                    'user3@example.com', '5555551234',
                ],
);

# Contact ID Event Codes
my %events = (
        # 100 - Medical Alarms
        100 => "Medical",
        101 => "Personal Emergency",
        102 => "Fail To Report In",

        # 110 - Fire Alarms
        110 => "Fire",
        111 => "Smoke",
        112 => "Combustion",
        113 => "Water Flow",
        114 => "Heat",
        115 => "Pull Station",
        116 => "Duct",
        117 => "Flame",
        118 => "Near Alarm",

        # 120 - Panic Alarms
        120 => "Panic",
        121 => "Duress",
        122 => "Silent",
        123 => "Audible",
        124 => "Duress - Access Granted",
        125 => "Diress - Egress Granted",

        # 130 - Burglar Alarms
        130 => "Burglary",
        131 => "Perimeter",
        132 => "Interior",
        133 => "24 Hour",
        134 => "Entry/Exit",
        135 => "Day/Night",
        136 => "Outdoor",
        137 => "Tamper",
        138 => "Near Alarm",
        139 => "Intrusion Verifier",

        # 140 - General Alarm
        140 => "General Alarm",
        141 => "Polling Loop Open",
        142 => "Polling Loop Short",
        143 => "Expansion Module Failure",
        144 => "Sensor Tamper",
        145 => "Expansion Module Tamper",
        146 => "Silent Burglary",
        147 => "Sensor Supervision Failure",

        # 150 and 160 - 24 Hour Non-Burglary
        150 => "24 Hour Non-Burglary",
        151 => "Gas Detected",
        152 => "Refrigeration",
        153 => "Loss of Heat",
        154 => "Water Leak",
        155 => "Foil Break",
        156 => "Day Trouble",
        157 => "Low Bottled Gas Level",
        158 => "High temp",
        159 => "Low temp",
        161 => "Loss of air flow",
        162 => "Carbon Monoxide detected",
        163 => "Tank level",

        # 200 and 210 - Fire Supervisory
        200 => "Fire Supervisory",
        201 => "Low Water Pressure",
        202 => "Low CO2",
        203 => "Gate Valve Sensor",
        204 => "Low Water Level",
        205 => "Pump Activated",
        206 => "Pump Failure",

        # 300 and 310 - System Troubles
        300 => "System Trouble",
        301 => "AC Loss",
        302 => "Low System Battery",
        303 => "RAM Checksum Bad",
        304 => "ROM Checksum Bad",
        305 => "System Reset",
        306 => "Panel Programming Changed",
        307 => "Self-Test Failure",
        308 => "System Shutdown",
        309 => "Battery Test Failure",
        310 => "Ground Fault",
        311 => "Battery Missing/Dead",
        312 => "Power Supply Overcurrent",
        313 => "Engineer Reset",

        # 320 - Sounder / Relay Troubles
        320 => "Sounder/Relay Trouble",
        321 => "Bell 1 Trouble",
        322 => "Bell 2 Trouble",
        323 => "Alarm Relay Trouble",
        324 => "Trouble Relay",
        325 => "Reversing Relay Trouble",
        326 => "Notification Appliance Ckt. #3 Trouble",
        327 => "Notification Appliance Ckt. #4 Trouble",

        # 330 and 340 - System Peripheral Trouble
        330 => "System Peripheral Trouble",
        331 => "Polling Loop Open",
        332 => "Polling Loop Short",
        333 => "Expansion Module Failure",
        334 => "Repeater Failure",
        335 => "Local Printer Out Of Paper",
        336 => "Local Printer Failure",
        337 => "Exp. Module DC Loss",
        338 => "Exp. Module Low Batt.",
        339 => "Exp. Module Reset",
        341 => "Exp. Module Tamper",
        342 => "Exp. Module AC Loss",
        343 => "Exp. Module Self-Test Fail",
        344 => "RF Receiver Jam Detect",

        # 350 and 360 - Communication Troubles
        350 => "Communication Trouble",
        351 => "Telco 1 Fault",
        352 => "Telco 2 Fault",
        353 => "Long Range Radio Xmitter Fault",
        354 => "Failure To Communicate Event",
        355 => "Loss Of Radio Supervision",
        356 => "Loss Of Central Polling",
        357 => "Long Range Radio Vswr Problem",

        # 370 - Protection Loop
        370 => "Protection Loop",
        371 => "Protection Loop Open",
        372 => "Protection Loop Short",
        373 => "Fire Trouble",
        374 => "Exit Error Alarm (Zone)",
        375 => "Panic Zone Trouble",
        376 => "Hold-Up Zone Trouble",
        377 => "Swinger Trouble",
        378 => "Cross-Zone Trouble",

        # 380 - Sensor Trouble
        380 => "Sensor Trouble",
        381 => "Loss Of Supervision - RF",
        382 => "Loss Of Supervision - RPM",
        383 => "Sensor Tamper",
        384 => "RF Low Battery",
        385 => "Smoke Detector Hi Sensitivity",
        386 => "Smoke Detector Low Sensitivity",
        387 => "Intrusion Detector Hi Sensitivity",
        388 => "Intrusion Detector Low Sensitivity",
        389 => "Sensor Self-Test Failure",
        391 => "Sensor Watch Trouble",
        392 => "Drift Compensation Error",
        393 => "Maintenance Alert",

        # 400 and 440 and 450 - Open/Close
        400 => "Open/Close",
        401 => "O/C By User",
        402 => "Group O/C",
        403 => "Automatic O/C",
        404 => "Late To O/C ",
        405 => "Deferred O/C",
        406 => "Cancel",
        407 => "Remote Arm/Disarm",
        408 => "Quick Arm",
        409 => "Keyswitch O/C",
        441 => "Armed Stay",
        442 => "Keyswitch Armed Stay",
        450 => "Exception O/C",
        451 => "Early O/C",
        452 => "Late O/C",
        453 => "Failed To Open",
        454 => "Failed To Close",
        455 => "Auto-Arm Failed",
        456 => "Partial Arm",
        457 => "Exit Error (User)",
        458 => "User On Premises",
        459 => "Recent Close",
        462 => "Legal Code Entry",
        463 => "Re-Arm After Alarm",
        464 => "Auto-Arm Time Extended",
        465 => "Panic Alarm Reset",
        466 => "Service On/Off Premises",

        # 410 - Remote Access
        411 => "Callback Request Made",
        412 => "Successful Download/Access",
        413 => "Unsuccessful Access",
        414 => "System Shutdown Command Received",
        415 => "Dialer Shutdown Command Received",
        416 => "Successful Upload",

        # 420 and 430 - Access Control
        421 => "Access Denied",
        422 => "Access Report By User",
        423 => "Forced Access",
        424 => "Egress Denied",
        425 => "Egress Granted",
        426 => "Access Door Propped Open",
        427 => "Access Point Door Status Monitor Trouble",
        428 => "Access Point Request To Exit Trouble",
        429 => "Access Program Mode Entry",
        430 => "Access Program Mode Exit",
        431 => "Access Threat Level Change",
        432 => "Access Relay/Trigger Fail",
        433 => "Access Rte Shunt",
        434 => "Access Dsm Shunt",

        # 500 and 510 - System Disables
        501 => "Access Reader Disable",

        # 520 - Sounder / Relay Disables
        520 => "Sounder/Relay Disable",
        521 => "Bell 1 Disable",
        522 => "Bell 2 Disable",
        523 => "Alarm Relay Disable",
        524 => "Trouble Relay Disable",
        525 => "Reversing Relay Disable",
        526 => "Notification Appliance Ckt. # 3 Disable",
        527 => "Notification Appliance Ckt. # 4 Disable",

        # 530 and 540 - System Peripheral Disables
        531 => "Module Added",
        532 => "Module Removed",

        # 550 and 560 - Communication Disables -
        551 => "Dialer Disabled",
        552 => "Radio Transmitter Disabled",
        553 => "Remote Upload/Download Disabled",

        # 570 - Bypasses
        570 => "Zone/Sensor Bypass",
        571 => "Fire Bypass",
        572 => "24 Hour Zone Bypass",
        573 => "Burg. Bypass",
        574 => "Group Bypass",
        575 => "Swinger Bypass",
        576 => "Access Zone Shunt",
        577 => "Access Point Bypass",

        # 600 and 610 - Test/Misc.
        601 => "Manual Trigger Test Report",
        602 => "Periodic Test Report",
        603 => "Periodic RF Transmission",
        604 => "Fire Test",
        605 => "Status Report To Follow",
        606 => "Listen-In To Follow",
        607 => "Walk Test Mode",
        608 => "Periodic Test - System Trouble Present",
        609 => "Video Xmitter Active",
        611 => "Point Tested OK",
        612 => "Point Not Tested",
        613 => "Intrusion Zone Walk Tested",
        614 => "Fire Zone Walk Tested",
        615 => "Panic Zone Walk Tested",
        616 => "Service Request",

        # 620 - Event Log
        621 => "Event Log Reset",
        622 => "Event Log 50% Full",
        623 => "Event Log 90% Full",
        624 => "Event Log Overflow",
        625 => "Time/Date Reset",
        626 => "Time/Date Inaccurate",
        627 => "Program Mode Entry",
        628 => "Program Mode Exit",
        629 => "32 Hour Event Log Marker",

        # 630 - Scheduling
        630 => "Schedule Change",
        631 => "Exception Schedule Change",
        632 => "Access Schedule Change",

        # 640 - Personnel Monitoring
        641 => "Senior Watch Trouble",
        642 => "Latch-Key Supervision",

        # 650 - Misc.
        651 => "Reserved For Ademco Use",
        652 => "Reserved For Ademco Use",
        653 => "Reserved For Ademco Use",
        654 => "System Inactivity",
);

# Contact ID Event Qualifiers
my %eventQual = (
        1 => "New Event or Opening",
        3 => "New Restore or Closing",
        6 => "Previously Reported",
);

my %eventQualAlarm = (
        1 => "New",
        3 => "Restored",
        6 => "Previously Reported",
);

my %eventQualOC = (
        1 => "Opening",
        3 => "Closing",
        6 => "Previously Reported",
);

# Contact ID digit value map
my %map = (
        '0' => 10,
        '1' => 1,
        '2' => 2,
        '3' => 3,
        '4' => 4,
        '5' => 5,
        '6' => 6,
        '7' => 7,
        '8' => 8,
        '9' => 9,
        'B' => 11,
        'C' => 12,
        'D' => 13,
        'E' => 14,
        'F' => 15,
        );
my %rmap = reverse %map; 

my $dbh = DBI->connect($dbi, $dbiUser, $dbiPassword)
    or die($DBI::errstr);

my $dir = IO::Dir->new($spoolDir);
if (defined $dir) {
    while (defined($_ = $dir->read)) {
        next unless /^event/;
        print "Processing event file: $_\n";
        processEvents($_);
    }
}
else {
    print "Failed to open $spoolDir\n";
}

$dbh->disconnect;


sub processEvents {
    my $eventFile = shift;
    my $meta = 0;
    my $events = 0;
    my %metadata;

    # delete after processing (disable for testing)
    my $deleteFile = 1;

    # open the file
    open(my $fh, '<', "$spoolDir/$eventFile")
        or die "Could not open file '$eventFile' $!";

    # process lines in file
    while (<$fh>) {
        next if /^\n/;
        s/\n//;  

        # file has two sections: [metadata] and [events]
        if ($_ =~ /^\[metadata\]$/) {
            print "Begin metadata...\n";
            $meta = 1;
            $events = 0;
            next;
        }
        if ($_ =~ /^\[events\]$/) {
            print "Begin events...\n";
            $meta = 0;
            $events = 1;
            next;
        }

        if ($meta) {
            s/\r?\n$//;
            if (/([^=]+)=(.*)/) {
                $metadata{substr(lc($1), 0, 80)} = substr($2, 0, 80);
            }
        }
        
        elsif ($events) {
            # Translate DTMF into Contact ID values
            s/B/E/;  # DTMF B is Contact ID E
            s/C/F/;  # DTMF C is Contact ID F
            s/\*/B/; # DTMF * is Contact ID B
            s/#/C/;  # DTMF # is Contact ID C
            s/A/D/;  # DTMF A is Contact ID D

            # Contact ID event format
            # ACCT MT QXYZ GG CCC S
            #
            # ACCT = 4 Digit Account number (0-9, B-F)
            # MT = Message Type. either 18 (preferred) or 98 (optional)
            # Q = Event qualifier
            # XYZ = Event code (3 Hex digits 0-9,B-F)
            # GG = Group or Partition number (2 Hex digits 0-9, B-F).
            #      00 to indicate that no specific group or partition information applies.
            # CCC = Zone number (Event reports) or User # (Open / Close reports ) (3 Hex digits 0-9,B-F ).
            #       000 to indicate that no specific zone or user information applies
            # S = 1 Digit Hex checksum
            #     (Sum of all message digits + S) MOD 15 = 0
            if ($_ =~ /^([0-9B-F]{4})(18|98)(1|3|6)([0-9B-F]{3})([0-9B-F]{2})([0-9B-F]{3})([0-9B-F]{1})$/) {

                # skip if checksum failed
                if (!checksum($7)) {
                    print "Skipping event $_: checksum failed!\n";
                    next;
                }

                # skip unknown events from unknown accounts
                if (!defined($accts{$1})) {
                    print "Skipping event $_: unknown account $1\n";
                    next;
                }

                # insert event into database
                storeEvent(\%metadata, $1, $4, $_);

                # process notifications for event
                notifyEvent(\%metadata, $1, $3, $4, $5, $6);

                print "Account: $accts{$1}\n";
                print "Qual: $3 ".$eventQual{$3}."\n";
                print "Event: $4 ".$events{$4}."\n";
                print "Group: $5  Zone: $6\n";
                print "\n";

            }
            else {
                print "Bad data: $_\n";
            }
        }

        else {
            next;
        }
    }

    close $fh;

    if ($deleteFile) {
        print "delete $spoolDir/$eventFile\n";
        unlink "$spoolDir/$eventFile";
    }

}

sub notifyEvent {
    my $metadata = shift;
    my $account = shift;
    my $qual = shift;
    my $event = shift;
    my $group = shift;
    my $zone = shift;

    # don't notify for these events
    return if ($event == '602'); # routine test

    # start with undefined message
    my $notifyString = undef;

    # 100 series - Alarms
    if ($event =~ /1[0-9]{2}/) {
        $notifyString = sprintf("%s\nAlarm: %s \nZone: %s (%s)",
                $accts{$account}, $events{$event}, $zone, $eventQualAlarm{$qual});
    }

    # 200 Series - Fire Supervisory
    if ($event =~ /2[0-9]{2}/) {
        $notifyString = sprintf("%s\nAlarm: %s \nZone: %s (%s)",
                $accts{$account}, $events{$event}, $zone, $eventQualAlarm{$qual});
    }

    # 300 Series - Troubles
    if ($event =~ /3[0-9]{2}/) {
        if ($event == '350') {
            #350 => "Communication Trouble"
            $notifyString = sprintf("%s %s Line %s (%s)",
                    $accts{$account}, $events{$event}, $zone, $eventQualAlarm{$qual});
        }
        elsif ($event == '354') {
            #354 => "Failure To Communicate Event"
            $notifyString = sprintf("%s %s Account %s (%s)",
                    $accts{$account}, $events{$event}, $zone, $eventQualAlarm{$qual});
        }
        elsif ($zone != 000) {
            $notifyString = sprintf("%s\nAlarm: %s \nZone: %s (%s)",
                    $accts{$account}, $events{$event}, $zone, $eventQualAlarm{$qual});
        }
        elsif ($group != 00) {
            $notifyString = sprintf("%s\nAlarm: %s \nModule: %s (%s)",
                    $accts{$account}, $events{$event}, $group, $eventQualAlarm{$qual});
        }
        else {
            $notifyString = sprintf("%s\n%s (%s)", $accts{$account}, $events{$event}, $eventQualAlarm{$qual});
        }
    }

    # 400 Series - Open/Close and Access
    if ($event =~ /4[0-9]{2}/) {
        if ($zone ne '000' && $group ne '00') {
            $notifyString = sprintf("%s\n%s: %s %s Partition %s", $accts{$account}, $eventQualOC{$qual}, $events{$event}, $zone, $group);
        }
        else {
            $notifyString = sprintf("%s\n%s: %s", $accts{$account}, $eventQualOC{$qual}, $events{$event});
        }
    }

    # 601 Manual Trigger Test Report
    # 608 Periodic Test - System Trouble Present
    if ($event == '608' || $event == '601') {
        $notifyString = sprintf("%s\n%s", $accts{$account}, $events{$event});
    }

    # append timestamp
    if (defined($notifyString)) {
        $notifyString .= "\n$$metadata{'timestamp'}";
    }
    
    if (defined($notifyString)) {
        #print "NOTIFY: $notifyString\n";
        foreach (@{$notify{$account}}) {
            if (/^[0-9]{10}$/) {
                print "Notify SMS: $_\n";
                open(my $sms, '|-', "/usr/local/bin/smsclient.pl -p $_")
                    or die "Could not open smsclient.pl' $!";
                print $sms $notifyString;
                close $sms;
            }
            else {
                print "Notify Email $_\n";
                my $msg = MIME::Lite->new(
                        From    =>  $emailFrom,
                        To      =>  $_,
                        Subject =>  "Alarm Event for $accts{$account} at $$metadata{'timestamp'}",
                        Type    =>  'text/plain; charset=utf-8',
                        Data    =>  $notifyString
                        );
                $msg->add("Auto-Submitted" => "auto-generated");
                $msg->send;
            }
        }
    }

}

# stores an event in the database
sub storeEvent {
    my $metadata = shift;
    my $account = shift;
    my $cidevent = shift;
    my $event = shift;

    print $$metadata{'timestamp'}."\n";

    # parse timestamp from file metadata
    # Tue May 02, 2017 @ 21:00:01 PDT
    my $strp = DateTime::Format::Strptime->new(
            pattern => '%a %b %d, %Y @ %H:%M:%S',
            time_zone => $timezone
            );
    my $dt = $strp->parse_datetime($$metadata{'timestamp'});

    # format timestamp for mysql
    my $timestamp = DateTime::Format::MySQL->format_datetime($dt);

    # insert data
    $dbh->do(q{
            INSERT INTO alarmreceiver
            (timestamp, account, event, protocol, callingfrom, callername)
            VALUES (?, ?, ?, ?, ?, ?)
            },
            undef,
            $timestamp, $account, $event, $$metadata{'protocol'}, $$metadata{'callingfrom'}, $$metadata{'callername'}
        ) or die($DBI::errstr);

    # 601 Manual Trigger Test Report
    # 602 Periodic Test Report
    if ($cidevent == '602' || $cidevent == '601') {
        $dbh->do(q{
                UPDATE alarmreceiver_test
                SET timestamp = ?
                WHERE account = ?
                },
                undef,
                $timestamp, $account
            ) or die($DBI::errstr);
    }
}

# Contact ID Checksum
sub checksum {
    # (Sum of all message digits + S) MOD 15 = 0

    my $sum = 0;
    foreach my $c (split //) {
        $sum += $map{$c};
    }
    
    # if result is 0, use digit F for checksum.
    if ($sum == 0) { $sum = $map{'F'}; }

    # return 1 if checksum ok, 0 if not
    return ($sum % 15) ? 0 : 1;
}
