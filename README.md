# puppetdblite

This script parses the most recent report from each host in the reports dir on
the puppet master and populates a sqlite db with the host to resource mapping.

The intention is that one could run this script in a cronjob so that when needed
they can easily query for hosts that have a specific classes or resources applied.

Future releases will create a CLI interface to perform queries but for now the
following example query (which lists all hosts with the Motd class) is provided:

```sql
SELECT hosts.host
FROM ((hosts
INNER JOIN host_resources on hosts.id = host_resources.host_id
INNER JOIN resources on resources.id = host_resources.resource_id))
WHERE resources.name = 'Motd';
```

