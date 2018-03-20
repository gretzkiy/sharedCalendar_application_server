#!/bin/bash
kill $(cat /var/www/app/tmp/pids/unicorn.pid) && unicorn -c unicorn.rb