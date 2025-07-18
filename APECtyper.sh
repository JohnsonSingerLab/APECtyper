#!/bin/bash

#=========== APEC Typing Pipeline ===========#

# Required Software:
## ECTyper (https://github.com/phac-nml/ecoli_serotyping)
## mlst (https://github.com/tseemann/mlst)
## NCBI BLAST+ blastn
## R

#---------------------------- Globals --------------------------------

VERSION="APECtyper v.1.0 (Apr. 2022)"     # current version: 1.0 (Apr. 2022)
DIR=$( dirname "${BASH_SOURCE[0]}" )      # source directory
DATE=$( date +%Y-%m-%d )                  # today's date
DB_APEC="${DIR}/db/apec_refs.fa"          # APEC ref database location
CITATION="Johnson TJ, Miller EA, Flores-Figueroa C, Munoz-Aguayo J, Cardona C, Fransen K, Lighty M, Gonder E, Nezworski J, Haag A, Behl M, Kromm M, Wileman B, Studniski M, Strain E, McDermott P, Singer RS. Refining the definition of the avian pathogenic Escherichia coli (APEC) pathotype through inclusion of high-risk clonal groups."    # APECtyper citation

#--------------------------- Functions -----------------------------------

function printUsage () {
	printf "Usage: APECtyper.sh [OPTIONS] -f [FASTA] -o [DIR]\n"
	printf "\t-h\tprint this usage message\n"
	printf "\t-v\tprint the version\n"
	printf "\t-r\tprint citation\n"
	printf "\t-d\tcheck for dependencies\n"
	printf "\t-f\tFASTA contig file or directory containing multiple FASTA files\n"
	printf "\t-o\toutput directory\n"
	printf "\t-i\tminimum blast percent identity [default: 90]\n"
	printf "\t-c\tminimum blast percent coverage [default: 90]\n"
	printf "\t-t\tnumber of threads to use [default: 1]\n"
	printf "\t-s\tcombine reports from multiple samples into single TSV file\n"
}

function checkDependency () {
    PACKAGE=$(command -v $1)
    if [ -z "$PACKAGE" ]; then
        echo -e "Error: dependency $1 could not be located." && exit 1
        else
        echo -e "Found "$1": $PACKAGE"
    fi
}

function checkAllDependencies () {
    checkDependency ectyper
    checkDependency mlst
    checkDependency blastn
    checkDependency R
}

function serotypeAnalysis () {
    echo "Running ECTyper..."
    ectyper -i $FASTA -o ${OUTDIR}/serotype/serotype_${NAME} --cores $THREADS --verify --percentIdentityOtype 90 --percentIdentityHtype 90 --percentCoverageOtype 70 --percentCoverageHtype 70 > /dev/null 2>&1
}

function mlstAnalysis () {
    echo "Running mlst..."
    mlst --scheme ecoli_achtman_4 $FASTA --label $NAME --threads $THREADS > ${OUTDIR}/mlst/mlst_results_${NAME}.tsv 2> $OUTDIR/mlst/mlst.log
}

function makeBlastDB () {
    echo "Making BLASTn database..."
    cp $DIR/db/apec_refs.fa $OUTDIR
    makeblastdb -in $OUTDIR/apec_refs.fa -dbtype nucl -title "APEC Ref Seqs" -logfile $OUTDIR/blast/makeblastdb.log 
}

function blastAnalysis () {
    echo "Running BLASTn..."
    blastn -query $FASTA -db $OUTDIR/apec_refs.fa -num_threads $THREADS -outfmt "6 qseqid sseqid slen length mismatch gaps qstart qend sstart send pident evalue bitscore" -out ${OUTDIR}/blast/blast_results_${NAME}.tsv 2> $OUTDIR/blast/blastn.log
}

function generateReport () {
   echo "Generating report..."
   Rscript "$DIR/bin/outputProcessing.R" "$NAME" "$OUTDIR" "$PERC_COVERAGE" "$PERC_IDENTITY" 2> $OUTDIR/report.log
}

function compileReports () {
   tail -1 ${OUTDIR}/pathotype_results_${NAME}.tsv >> ${OUTDIR}/pathotype_results_summary.tsv
   tail -n +2 ${OUTDIR}/blast_results_${NAME}.tsv | sed "s/^/${NAME}\t/"  >> ${OUTDIR}/blast_results_summary.tsv
}

function cleanupOutdir () {
    echo "Cleaning up..."
    rm -f $OUTDIR/*.tmp
    rm -f $OUTDIR/apec_refs.fa*
}

#------------------------------- Options ---------------------------------

# Set defaults
THREADS=1            # default number of threads to use with mlst and BLAST
PERC_IDENTITY=90     # default minimum blast percent identity
PERC_COVERAGE=90     # default minimum blast percent coverage
SUMMARIZE='false'

# Parse command options and arguments
while getopts 'vhrdf:o:i:c:t:s' flag; do
  case "${flag}" in
    v) echo "$VERSION"
       exit 0 ;;
    h) printUsage
       exit 0 ;;
    r) echo -e "\n$CITATION\n"
       exit 0 ;;
    d) checkAllDependencies
       exit 0 ;;
    f) INPUT=$OPTARG;;            # name of input FASTA file or directory (required)
    o) OUTDIR=$OPTARG;;           # name of output directory (required)
    i) PERC_IDENTITY=$OPTARG;;    # minimum blast percent identity (optional)
    c) PERC_COVERAGE=$OPTARG;;    # minimum blast percent coverage (optional)
    t) THREADS=$OPTARG;;          # number of threads for running mlst and BLAST 
    s) SUMMARIZE='true'           # whether to summarize all sample results into a single output file
  esac
done

# If no variables, print usage message and exit
[[ $# == 0 ]] && { printUsage ; exit 1; }

#------------------------------- Welcome ---------------------------------

echo "============== Running APECtyper =================="
echo $VERSION
echo "Starting run on $DATE"

#------------------------------- Checks ---------------------------------

# exec >${OUTDIR}/logfile.out 2>&1

# Check for empty input variables
[[ -z "$INPUT" ]] && { echo "Error: Missing an input contig file or directory." ; printUsage ; exit 1; }
[[ -z "$OUTDIR" ]] && { echo "Error: Missing a specified output directory." ; printUsage ; exit 1; }

# Check that input file/directory exists
[[ ! -f "$INPUT" ]] && [[ ! -d "$INPUT" ]] && { echo "Error: Input file/directory does not exist." ; exit 1; }

# Check for dependencies 
checkAllDependencies

# Check that output directory does not already exist
[[ -d "$OUTDIR" ]] && { echo "Error: Output directory already exists." ; exit 1; }

#---------------------------- Set-up ---------------------------------

# Create serotype, mlst, and BLAST output directories
mkdir -p ${OUTDIR}/serotype
mkdir -p ${OUTDIR}/mlst
mkdir -p ${OUTDIR}/blast

# Build temp blast database
makeBlastDB
        # if non-zero exit status, print error and exit
        [[ $? -ne 0 ]] && { echo "Error when running makeblastdb. See makeblastdb.log for more details." ; exit 1; }
    
# Generate list of input FASTA files
if [[ -f "$INPUT" ]]; then
    echo "$INPUT" > ${OUTDIR}/contigFiles.tmp
elif [[ -d "$INPUT" ]]; then
    find "$INPUT" -maxdepth 1 -type f \( -iname \*.fasta -o -iname \*.fa -o -iname \*.fna \) > ${OUTDIR}/contigFiles.tmp
fi

COUNT=$(cat ${OUTDIR}/contigFiles.tmp | wc -l)

# Create empty summary files with headers (optional)
if [[ "$SUMMARIZE" == 'true' ]] && [[ $COUNT -gt 1 ]]; then
   echo -e "Sample\tSpecies\tSerotype\tSerotypeQC\tST\tAPEC_plasmid\tPathotype" > ${OUTDIR}/pathotype_results_summary.tsv
   echo -e "Sample\tSequence\tGene\tGeneLength\tAlignmentLength\tMismatches\tGaps\tSequenceStart\tSequenceEnd\tGeneStart\tGeneEnd\tIdentity\tEvalue\tBitscore\tCoverage" >${OUTDIR}/blast_results_summary.tsv
fi

#------------------------- Run for loop ------------------------------

# MLST and BLAST of each input fasta file ####
for FASTA in $(cat ${OUTDIR}/contigFiles.tmp); do
    
    FILE=${FASTA##*/}
    NAME=${FILE%.*}
    
    echo "Starting analysis of ${NAME}..."
    
    ##### STEP 1: ECTyper #####
    serotypeAnalysis
        # if non-zero exit status, print error and exit
        [[ $? -ne 0 ]] && { echo "Error when running ECTyper. See serotype/ectyper.log for more details." ; exit 1; }
        # [[ $SPECIES != *"Escherichia coli"* ]] && { echo "Error: Isolate is not E. coli. Skipping..." ; continue; }
    
    ##### Step 2: mlst #####
    mlstAnalysis
        # if non-zero exit status, print error and exit
        [[ $? -ne 0 ]] && { echo "Error when running mlst. See mlst/mlst.log for more details." ; exit 1; }
    
    ##### Step 3: BLAST ##### 
    blastAnalysis
        # if non-zero exit status, print error and exit
        [[ $? -ne 0 ]] && { echo "Error when running blastn. See blast/blastn.log for more details." ; exit 1; }

    ##### Step 4: Generate Report ##### 
    generateReport
        # if non-zero exit status, print error and exit
        [[ $? -ne 0 ]] && { echo "Error when generating report in R. See report.log for more details." ; exit 1; }

    ##### Step 5: Compile Reports (optional) ##### 
    [[ "$SUMMARIZE" == 'true' ]] && [[ $COUNT -gt 1 ]] && compileReports
    
    echo -e "Analysis of ${NAME} is complete.\n" 

done
    
#------------------------- Clean-up -------------------------------    

cleanupOutdir
        # if non-zero exit status, print error and exit
        [[ $? -ne 0 ]] && { echo "Error when removing temp files from output directory." ; exit 1; }

#------------------------- Good-bye -------------------------

echo "============== APECtyper is complete =================="
echo -e "Please cite: \n$CITATION"

exit 0
