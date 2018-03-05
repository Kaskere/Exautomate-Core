#!/bin/bash
###### Authors: Brent Davis and Jacqueline Dron
###### Exautomate: Bash script based utility to speed up exome analysis.
###### Requirements: R (plus packages), Java, GATK, Plink, Vcftools, Annovar.
clear
echo "Welcome to Ex-Automate."
choice=0

while [ $choice -ne 5 ]; do
  printf " 1: Pre-merged vcf \n 2: Merge case and control vcf for analysis. \n 3: Retrieve 1000 Genomes options \n 4: Synthetic run \n 5: Exit \n"
  read -p "Enter (1-4): " choice
  if [ $choice -eq 1 ]; then

    ls ../input/*.vcf
    read -e -p "Enter the vcf file you would like to analyze: " vcfInput
    echo ""

    #If there are comments (eg lines starting with #) mid-vcf file then this command is invalid. However, there should not be.
    headerLines=$(grep -o '#' $vcfInput | wc -l)

    read -e -p "Enter the number of controls in your vcf file. Script assumes vcf is all controls, then all cases: " numControls
    echo ""

    read -e -p "Choose filename for processed vcf (include .vcf): " vcfOutput
    echo ""

    read -e -p "Choose filename for output plink files (no extension): " plinkOutput
    echo ""

  echo "Kernels: linear, linear.weighted, quadratic, IBS, 2wayIX"
  read -p "Enter the kernel to be used in the analysis: " kernel
  echo ""

#Handles the choice of methods that are available for different kernels.
  if [ "$kernel" == "linear" ] || [ "$kernel" == "linear.weighted" ]; then
    read -p "Choose SKAT or SKAT-O: " choice
    if [ "$choice" == "SKAT-O" ]; then
      method = "optimal.adj"
    else
      method = "davies"
    fi
  else
    method = "davies"
  fi

  ./ExautomateBackEnd ../dependencies/hg_19.fasta $vcfInput $vcfOutput $headerLines $plinkOutput $kernel $numControls $method
    #make a file called kernellist.txt with all valid kernel names.

  elif [ $choice -eq 2 ]; then

    ls  ../input/*.vcf
    read -e -p 'Enter the name of the control vcf: ' controlvcf
    numControls=$(awk '{if ($1 == "#CHROM"){print NF-9; exit}}' $controlvcf)
    echo "Detecting " $numControls " controls"
    echo ""

    ls  ../input/*.vcf
    read -e -p "Enter the name of the cases vcf: " casesvcf
    echo ""

    #make sure it is .vcf
    read -e -p "Enter the name of the output file: " vcfInput

    ./MergeVCFs.sh $controlvcf $casesvcf ../dependencies/hg19.fasta $vcfInput

    #read -e -p "Enter the desired name of the processed vcf: "

    read -e -p "Choose filename for output plink files (no extension): " plinkOutput
    echo ""


    #Add list of kernels for user to see.
    read -e -p "Enter the kernel to be used in the analysis: " kernel
    echo ""

  #Handles the choice of methods that are available for different kernels.
    if [ "$kernel" == "linear" ] || [ "$kernel" == "linear.weighted" ]; then

      read -p "Choose SKAT ( 1 ) or SKAT-O ( 2 ): " choice

      if [ "$choice" == 2 ]; then
        method = "optimal.adj"
      else
        method = "davies"
      fi

    #Default to davies if the kernel can't do SKAT-O.

    else
      method = "davies"
    fi


  ./ExautomateBackEnd ../dependencies/hg_19.fasta $vcfInput $vcfOutput $headerLines $plinkOutput $kernel $numControls $method



  elif [ $choice -eq 3 ]; then
  #Requires wget and vcftools
  #Fragile. If the location of the 1000 genome files are moved then this will fail.

    mkdir ./1000gvcf

    #change the *.vcf.* pattern to get different files.
    # -r is recursive search down
    # -l1 is a max recursion depth of 1 (avoid downloading supporting files)
    # --no-parent avoids going up the file path.
    # -A "*" specifies the pattern to download.
    # -R "*chrX*" rejects all files with chrX. This is because we're not including sex chromosomes or MT in our analysis. Modify as desired.
    # -nc is to avoid overwriting existing files.
    # -nd is to avoid downloading the directory tree and just the files.
    wget -r -l1 -nc -nd --no-parent -P ./1000gvcf -A '*.vcf.*' -R '*chrX*','*chrMT*','*wgs*','*chrY*' ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/

    #Very specific move function to move the downloaded files into the 1000gvcf folder.
    #mv ./ftp*/vol1/ftp/release/20130502/*.vcf.* ../../../../../1000gvcf/
    echo "Finished retrieval. Beginning concatenation."

    #Necessary for first time install. Exits quickly if already installed.
    ##apt install vcftools <- put into Installer.sh
    vcf-concat ./1000gvcf/*.vcf.gz | bgzip -c > ./1000gvcf/merged1000g.vcf.gz
    echo "Finished concatenation. Sorting."

    #When I run this, I set the -Xmx option based on my system. Typically to 50-60g
    mkdir ../tmpdir
    java -jar ../dependencies/picard.jar SortVcf I=./1000gvcf/merged1000g.vcf.gz O=../output/sorted1000g.vcf.gz TMP_DIR=../tmpdir/
    rm -r ../tmpdir

    ls *.bed
    ls ../dependencies/*.bed
    read -e -p "Enter the name of the .bed file to filter by: " bedFile

#Not sure this works with current tabix.
    tabix -T $bedFile merged1000gvcf.gz

    #Command to filter based on a list of names from the population files. Made in R.
    #bcftools view -s allButEur2.csv -S merged1000gbgzip.vcf.gz > allbuteur.bgzip.vcf.gz

    echo "Finished filtering file."

    read -p "Delete original thousand genome files? y/n: " deleteFlag
    if [ "$deleteFlag" -eq "y"  ]; then
        rm ./1000gvcf/*
    fi


  elif [ $choice -eq 4 ]; then

    ls ../input/*.sim
    read -p "Enter the filename of the .sim file to be used: " simInput
    echo ""


  read -p "Enter the kernel to run on the synthetic files: " kernel
  echo ""
  #Handles the choice of methods that are available for different kernels.
    if [ "$kernel" == "linear" ] || [ "$kernel" == "linear.weighted" ]; then
      read -p "Choose SKAT or SKAT-O: " choice
      if [ "$choice" == "SKAT-O" ]; then
        method = "optimal.adj"
      else
        method = "davies"
      fi
    else
      method = "davies"
    fi

    read -p "Enter the filename for the output: " outputName
    echo ""

    ./synthesizeSKATFiles.sh $simInput $outputName

    read -p "Enter the kernel to run on the synthetic files: " kernel
    echo ""

    echo "Running SKAT"
    Rscript RunSkat.R $outputName.bed $outputName.bim $outputName.fam $outputName.bim.SetID "SSD_File.SSD" $kernel $method
    echo "SKAT complete."
    mv $outputName.* ../output/$outputName.*


  else
    echo "Unknown input."
  fi
done
