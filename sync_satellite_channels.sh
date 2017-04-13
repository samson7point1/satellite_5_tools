#!/bin/bash
/bin/logger -t satellite ": job start [$0]"
satellite-sync
/bin/logger -t satellite ": job end [$0]"
