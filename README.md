![version](https://img.shields.io/badge/version-1.0.0-blue)
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-green.svg)](https://www.gnu.org/licenses/old-licenses/gpl-3.0.en.html)
[![made-with-bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)

:no_entry: **ATTENTION:** 
This version of APECtyper is deprecated. New web-based version coming soon!

# APECtyper

*In silico* command line tool for typing Avian Pathogenic *Escherichia coli* (APEC)
 
## Description

`APECtyper` is a Bash shell script that classifies Avian Pathogenic *Escherichia coli* (APEC) based on the revised APEC pathotyping scheme developed by [Johnson et al. *in prep*](). Preassembled partial or complete genome assemblies are run through two *E. coli* typing tools (namely, [ECTyper](https://github.com/phac-nml/ecoli_serotyping) and [mlst](https://github.com/tseemann/mlst)) and a report is generated summarizing the results of both programs along with the APEC pathotype classification. `APECtyper` also screens input assemblies for 46 APEC virulence genes compiled in a [custom APEC database](https://github.com/JohnsonSingerLab/APEC_VF_database) and generates a summary report.

<p align="center">
<img src=https://github.com/JohnsonSingerLab/APECtyper/blob/main/image/APEC_typing_scheme.png width="750">
</p>

## Dependencies

* [ECTyper](https://github.com/phac-nml/ecoli_serotyping) v1.0.0
* [mlst](https://github.com/tseemann/mlst) v2.19.0
* [NCBI BLAST+ blastn](https://www.ncbi.nlm.nih.gov/books/NBK569861/?report=reader&%2F%3Freport=reader)
    * This should already be installed as an mlst dependency. 
* [R](https://cran.r-project.org)

## Installation

Install the latest version directly from GitHub:

```
git clone https://github.com/JohnsonSingerLab/APECtyper.git
```

### Check Installation

Check APECtyper version:

```
./APECtyper.sh -v
```

Check that dependencies are installed in your path:

```
./APECtyper.sh -d
```

## Usage

### Input Requirements

* assembly in FASTA format or directory containing multiple assemblies in FASTA format (can be multiple contigs)
* directory name to output the results (to be created during run)

### Command Line Options

```
% ./APECtyper.sh
Usage: APECtyper.sh [OPTIONS] -f [FASTA or DIR] -o [DIR]
	-h	print this usage message
	-v	print the version
	-r	print citation
	-d	check for dependencies
	-f	FASTA contig file or directory containing multiple FASTA files
	-o	output directory
        -i      minimum blast % identity [default: 90]
	-c      minimum blast % coverage [default: 90]
	-t      number of threads to use [default: 1]
	-s      combine reports from multiple samples into single TSV file
```

### Basic Usage

Input is a single FASTA file:
```
./APECtyper.sh -f data/assemblies/sample1.fasta -o sample1_output
```

Input is a directory containing multiple FASTA files:
```
./APECtyper.sh -f data/assemblies -o multisample_output
```

## Output

Within the user-defined output directory, there will be three directories – `serotype`, `mlst`, and `blast` – containing the individual output files from ECTyper, mlst, and blastn, respectively. There will also be two TSV files per sample: 

* `pathotype_results_[SAMPLE].tsv`: A tab-separated file summarizing the outputs from ECtyper and mlst, as well as the pathotype classification.
* `blast_results_[SAMPLE].tsv`: A tab-separated summary of the blastn results against the custom APEC virulence gene database. 
* `report.log`: A log file for summary report generation.

If the `-s` flag is included when running `APECtyper.sh`, two additional files will be generated that are compilations of all blast reports and all pathotype reports: `blast_results_summary.tsv` and `pathotype_results_summary.tsv`.  

### Pathotype output

The `pathotype_results_[SAMPLE].tsv` file has the following columns:  

Column | Example | Description
-------|---------|------------
Sample | `sample1` | Name of input assembly file with file extension removed
Species | `Escherichia coli` | Species identified by ECTyper
Serotype | `O25:H4` | Serotype identified by ECTyper
SerotypeQC | `PASS (REPORTABLE)` | QC message produced by ECTyper (See [ECTyper page](https://github.com/phac-nml/ecoli_serotyping#quality-control-qc-module) for a description of all possible QC codes) 
ST | `131` | Sequence type identified by mlst
APEC_plasmid | `Present` | Whether or not APEC plasmid markers *hlyF* and *ompT* were found
Pathotype | `High Risk APEC` | Pathotype classification (possible values include `High Risk APEC`, `APEC`, `High Risk non-APEC`, `non-APEC`, or `Not E. coli`) *

\*NOTE: Occasionally, the ST or O-type cannot be determined. In these situations, there will be an added note in the 'Pathotype' column indicating that it is unknown whether the isolate is 'High Risk'.


### APEC virulence gene output

The `blast_results_[SAMPLE].tsv` file has the following columns:

Column | Example | Description
-------|---------|------------
Sequence | `contig00218` | Name of input assembly or specific assembly contig 
Gene | <code>papC&#124;Pap_pili&#124;CP000468.1</code> | APEC virulence gene name
GeneLength | `2520` | Length of gene (in bp)
AlignmentLength | `2520` | Length of sequence overlap (in bp)
Mismatches | `1` | Number of mismatches in the alignment
Gaps | `0` | Number of gaps in the alignment
SequenceStart | `2955` | Start of alignment in sequence
SequenceEnd | `5474` | End of alignment in sequence
GeneStart | `1` | Start of alignment in gene
GeneEnd | `2520` | End of alignment in gene
Identity | `99.96` | Percent of identical matches
Evalue | `0` | Expect value (see definition [here](https://blast.ncbi.nlm.nih.gov/Blast.cgi?CMD=Web&PAGE_TYPE=BlastDocs&DOC_TYPE=FAQ#expect))
Bitscore | `4649` | Bit score
Coverage | `100` | Percent coverage of the gene ( (AlignmentLength - Gaps) / GeneLength * 100 )

## Citations

```
./APECtyper.sh -r
```

If you use APECtyper in your work, please cite:  

* Johnson TJ, Miller EA, Flores-Figueroa C, Munoz-Aguayo J, Cardona C, Fransen K, Lighty M, Gonder E, Nezworski J, Haag A, Behl M, Kromm M, Wileman B, Studniski M, Strain E, McDermott P, Singer RS. Refining the definition of the avian pathogenic *Escherichia coli* (APEC) pathotype through inclusion of high-risk clonal groups. Poultry Science (2022) 101(10):102009. [doi: 10.1016/j.psj.2022.102009](https://pubmed.ncbi.nlm.nih.gov/35952599/)   

Please also cite:

* Bessonov K, Laing C, Robertson J, Yong I, Ziebell K, Gannon VPJ, Nichani A, Arya G, Nash JHE, Christianson S. ECTyper: *in silico Escherichia* coli serotype and species prediction from raw and assembled whole-genome sequence data. Microb Genom. (2021) 7(12):000728. [doi: 10.1099/mgen.0.000728](https://pubmed.ncbi.nlm.nih.gov/34860150/)
* Seemann T, `mlst` Github [https://github.com/tseemann/mlst](https://github.com/tseemann/mlst)
* Jolley KA, Bray JE, Maiden MCJ. Open-access bacterial population genomics: BIGSdb software, the PubMLST.org website and their applications. Wellcome Open Res. (2018) 3:124. [doi: 10.12688/wellcomeopenres.14826.1](https://pubmed.ncbi.nlm.nih.gov/30345391/)
