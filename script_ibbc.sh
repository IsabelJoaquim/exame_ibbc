#!/bin/bash

#1
# Load the conda environment
conda init
conda activate tools_qc
echo "Enviroment activated"

# Create main directory
echo "Creating directories..."
mkdir -p ~/exame/{raw_data,processed_data,results,logs}

# Move raw data to raw_data directory
echo "Moving raw data..."
scp exame_files/0_mM_NOD_plus_1_aaa.fastq.gz ~/exame/raw_data/
scp exame_files/0_mM_NOD_plus_2_aaa.fastq.gz ~/exame/raw_data/
scp exame_files/400_mM_NOD_plus_1_aaa.fastq.gz ~/exame/raw_data/
scp exame_files/400_mM_NOD_plus_2_aaa.fastq.gz ~/exame/raw_data/

echo "Directory structure created and raw data moved."

# Define directories
RAW_DIR=~/exame/raw_data
PROCESSED_DIR=~/exame/processed_data
RESULTS_DIR=~/exame/results
LOG_DIR=~/exame/logs

# Create log file
LOG_FILE=$LOG_DIR/process_log.txt
echo "Processing log" > $LOG_FILE

#2
# Function to count reads
count_reads() {
    zcat $1 | echo $((`wc -l`/4))
}

# Process each sample
for SAMPLE in $RAW_DIR/*.fastq.gz; do
    BASENAME=$(basename $SAMPLE .fastq.gz)
    
    # Step 1: FastQC before trimming
    echo "fastqc..."
    fastqc $SAMPLE -o $RESULTS_DIR
    
    # Step 2: Trimmomatic
    echo "trimmomatic..."
    trimmomatic PE -phred33 \
        $RAW_DIR/${BASENAME}_1_aaa.fastq.gz $RAW_DIR/${BASENAME}_2_aaa.fastq.gz \
        $PROCESSED_DIR/${BASENAME}_1_paired.fastq.gz $PROCESSED_DIR/${BASENAME}_1_unpaired.fastq.gz \
        $PROCESSED_DIR/${BASENAME}_2_paired.fastq.gz $PROCESSED_DIR/${BASENAME}_2_unpaired.fastq.gz \
        ILLUMINACLIP:TruSeq3-PE.fa:2:30:10 SLIDINGWINDOW:4:20 MINLEN:36
    
    # Step 3: FastQC after trimming
    echo "fastqc..."
    fastqc $PROCESSED_DIR/${BASENAME}_1_paired.fastq.gz -o $RESULTS_DIR
    fastqc $PROCESSED_DIR/${BASENAME}_2_paired.fastq.gz -o $RESULTS_DIR
    
    # Count reads before and after processing
    echo "Counting reads before..."
    READS_BEFORE=$(count_reads $SAMPLE)
    echo "Counting reads after..."
    READS_AFTER=$(count_reads $PROCESSED_DIR/${BASENAME}_1_paired.fastq.gz)
    echo "Done counting."
    
    # Log results
    echo "$BASENAME: Reads before = $READS_BEFORE, Reads after = $READS_AFTER" >> $LOG_FILE
done

# Step 4: MultiQC
echo "multiqc..."
multiqc $RESULTS_DIR -o $RESULTS_DIR

echo "Processing complete. Check $LOG_FILE for details."

#3
# Create summary report
SUMMARY_FILE=$RESULTS_DIR/summary_report.txt
echo "Sample Summary Report" > $SUMMARY_FILE
echo "=====================" >> $SUMMARY_FILE

# Append log file content to summary report
cat $LOG_DIR/process_log.txt >> $SUMMARY_FILE

echo "Summary report generated at $SUMMARY_FILE."

# # Generate visualization using Python
# python3 << EOF
# import matplotlib.pyplot as plt

# # Read log file
# log_file = "$LOG_DIR/process_log.txt"
# samples = []
# reads_before = []
# reads_after = []

# with open(log_file, 'r') as f:
#     for line in f:
#         if line.strip():
#             parts = line.split(':')
#             sample = parts[0].strip()
#             reads = parts[1].split(',')
#             reads_before.append(int(reads[0].split('=')[1].strip()))
#             reads_after.append(int(reads[1].split('=')[1].strip()))
#             samples.append(sample)

# # Create bar plot
# x = range(len(samples))
# plt.figure(figsize=(10, 5))
# plt.bar(x, reads_before, width=0.4, label='Reads Before', align='center')
# plt.bar(x, reads_after, width=0.4, label='Reads After', align='edge')
# plt.xlabel('Samples')
# plt.ylabel('Read Counts')
# plt.title('Read Counts Before and After Processing')
# plt.xticks(x, samples, rotation='vertical')
# plt.legend()
# plt.tight_layout()

# # Save plot
# plt.savefig('$RESULTS_DIR/read_counts_plot.png')
# EOF

echo "Summary report and visualization generated at $RESULTS_DIR."