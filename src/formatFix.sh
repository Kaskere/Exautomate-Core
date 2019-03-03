#!/bin/bash

##### Author Info ############################################################################
#     Brent Davis and Jacqueline Dron
#     University of Western Ontario, London, Ontario, Canada
#     2018
##############################################################################################

##### Description #############################################################################
#    formatFix
#    Fixes format inconsistancies in .vcf file that arise through the merging process.
###############################################################################################

##### Input Parameters ########################################################################
#   $1 is merged .vcf file (no extension)
#   $2 is # of header lines in .vcf file to be ignored
#   $3 is name for merged output .vcf file
###############################################################################################

echo "### Entering formatFix.sh ###"

file_name=$1
N=$(wc -l < $file_name)
L=$(($N-$2))
head -n $2 $1 > $1_top
tail -n $L $1 > $1_bottom
T=$1_top
B=$1_bottom

# Number of header lines
headerLines=$(grep -c "#" $1)

# This ensures that the genotype coding of the merged .vcf file is consistant.
sed -i 's/\.\/\./0\|0/g' $B
cat $T $B > $3.temp.vcf
bcftools annotate -x ^FORMAT/GT -o $3 $3.temp.vcf
rm $T
rm $B
rm $3.temp.vcf

echo "### Exiting formatFix.sh ###"
echo ""
