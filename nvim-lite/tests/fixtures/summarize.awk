#!/usr/bin/awk -f
# Sum request counts per service from the CSV above
BEGIN { FS = ","; OFS = "\t" }
NR == 1 { next }
{
    total[$2] += $3
    if ($4 > peak[$2]) peak[$2] = $4
}
END {
    printf "%-12s %10s %8s\n", "SERVICE", "REQUESTS", "PEAK_MS"
    for (svc in total) printf "%-12s %10d %8d\n", svc, total[svc], peak[svc]
}
