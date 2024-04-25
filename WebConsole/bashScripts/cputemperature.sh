#!/bin/bash
echo "scale=1; $(sort -nr /sys/class/hwmon/hwmon0/{temp2_input,temp3_input} | head -n1) / 1000" | bc