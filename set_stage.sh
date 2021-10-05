#!/bin/bash
#Purpose: show what stage any given package is at
#
#





STAGES=($(echo /var/www/html/bitaccess/{development,qa,staging,release{,/stage{1..5}}}))
PACKAGES=("docker_cloud_btm" "provisioner")

echo "Staging directories:"
SPACES="                                                                "
PREFIX=""
for i in ${!STAGES[*]};do
    echo "  $PREFIX${STAGES[i]}"
    [ ! -d ${STAGES[i]} ] && echo "      ERROR: ${STAGES[i]} is not a directory"
    PREFIX="${SPACES:0:$(($i*2))}\`->"
done
echo

echo "Packages:"
for i in ${!PACKAGES[*]};do
    echo "  ${PACKAGES[i]}"
done
echo



#TODO:
#  use dialog to give a small menu
#   base on stage or package
#   show what stage each package is at
#   show what is in each stage
#   move a package to next stage
