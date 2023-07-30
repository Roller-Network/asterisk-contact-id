--
-- Table structure for table `alarmreceiver`
--

DROP TABLE IF EXISTS `alarmreceiver`;
CREATE TABLE `alarmreceiver` (
    `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
    `timestamp` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
    `account` smallint(5) unsigned NOT NULL,
    `event` varchar(16) NOT NULL,
    `protocol` enum('ADEMCO_CONTACT_ID') NOT NULL,
    `callingfrom` varchar(80) NOT NULL DEFAULT '',
    `callername` varchar(80) NOT NULL DEFAULT '',
    PRIMARY KEY (`id`),
    KEY `account` (`account`),
    KEY `callingfrom` (`callingfrom`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Table structure for table `alarmreceiver_test`
--

DROP TABLE IF EXISTS `alarmreceiver_test`;

CREATE TABLE `alarmreceiver_test` (
    `account` smallint(5) unsigned NOT NULL,
    `test_interval` smallint(5) unsigned NOT NULL DEFAULT '24',
    `timestamp` timestamp NOT NULL DEFAULT '0000-00-00 00:00:00',
    PRIMARY KEY (`account`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
