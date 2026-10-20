#!/bin/bash
mysqldump -u plugnmeet -p'PlugnmeetDB123!' plugnmeet > /opt/backup/plugnmeet_$(date +%F).sql
