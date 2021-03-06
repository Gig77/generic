.PHONY: gsnap
gsnap: $(foreach S, $(SAMPLES), gsnap/$S.gsnap.bam)

# FASTA reference genome
# ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/phase2_reference_assembly_sequence/hs37d5.fa.gz
	
# build GMAP database
# cd /mnt/projects/chrisi/data/gsnap
# ~/tools/gmap-2014-05-15/util/gmap_build -d g1k_v37 /mnt/projects/generic/data/broad/human_g1k_v37.fasta
# cat /mnt/projects/generic/data/broad/human_g1k_v37.fasta /mnt/projects/chrisi/results/etv6-runx1.breakpoint.fa /mnt/projects/generic/data/ncbi/NC_001501_moloney_murine_leukemia_virus.fasta > /mnt/projects/chrisi/data/gsnap/human_g1k_v37_etv6runx1.fasta 
# ~/tools/gmap-2014-05-15/bin/gmap_build --dir=/mnt/projects/chrisi/data/gsnap --db=g1k_v37_etv6runx1 --circular MT,NC_001501.1 /mnt/projects/chrisi/data/gsnap/human_g1k_v37_etv6runx1.fasta
# rm /mnt/projects/chrisi/data/gsnap/human_g1k_v37_etv6runx1.fasta
#
# gunzip -c snp138.txt.gz | ~/tools/gmap-2014-05-15/bin/dbsnp_iit -w 1 > g1k_v37.snp138.txt
# cd g1k_v37_etv6runx1
# cat g1k_v37.snp138.txt | ~/tools/gmap-2014-05-15/bin/iit_store -o g1k_v37.snp138
# ~/tools/gmap-2014-05-15/bin/snpindex -d g1k_v37_etv6runx1 -D g1k_v37_etv6runx1 -v g1k_v37.snp138
# mv g1k_v37_etv6runx1/g1k_v37.snp138.iit g1k_v37_etv6runx1/g1k_v37_etv6runx1.maps

# for splicesites
# ?? gunzip -c refGene.txt.gz | psl_splicesites -s 1 > mm10splicesites #ok
# cat g1k_v37.splicesites | ~/tools/gmap-2014-05-15/bin/iit_store -o g1k_v37_etv6runx1.maps/g1k_v37.splicesites

# serialize gsnap runs with flock because they take a LOT of memory
# --novelsplicing=1 increases number of uniquely mapped protein-coding reads by only ~500 per sample
gsnap/%.gsnap.bam: $(PROJECT_HOME)/data/bam/%.bam
	mkdir -p gsnap
	flock -x .lock ~/tools/gmap-2014-05-15/src/gsnap \
			--db=g1k_v37_etv6runx1 \
			--dir=/mnt/projects/chrisi/data/gsnap/g1k_v37_etv6runx1 \
			--format=sam \
			--npaths=1 \
			--max-mismatches=1 \
			--novelsplicing=0 \
			--batch=4  \
			--quality-protocol=sanger \
			--print-snps \
			--nthreads=20 \
			--input-buffer-size=5000 \
			--use-splicing=g1k_v37.splicesites \
			--use-snps=g1k_v37.snp138 \
			--genome-unk-mismatch=0 \
			<(java -jar ~/tools/picard-tools-1.114/SamToFastq.jar VALIDATION_STRINGENCY=SILENT INPUT=$< FASTQ=/dev/stdout | ~/tools/fastx_toolkit-0.0.14/bin/fastx_trimmer -f $(TRIM_BEFORE_BASE)) \
		| ~/tools/samtools-0.1.19/samtools view -Shb - \
		| ~/tools/samtools-0.1.19/samtools sort -m 1000000000 - $@ \
		2>&1 | $(LOG)

	# unfortunately MarkDuplicates does not allow streaming, so we have to create a temporary file...
	mkdir -p picard
	java -Xmx2g -Djava.io.tmpdir=/data/tmp -jar ~/tools/picard-tools-1.114/MarkDuplicates.jar \
		INPUT=$@.bam \
		OUTPUT=$@.part \
		METRICS_FILE=picard/$*.mark_duplicates_metrics \
		VALIDATION_STRINGENCY=LENIENT \
		2>&1 | $(LOG)
		
	mv $@.part $@
	rm $@.bam
	~/tools/samtools-0.1.19/samtools index $@ 2>&1 | $(LOG)

gsnap/%.gsnap.filtered.bam: gsnap/%.gsnap.bam
	samtools view -h -F 772 $< | grep -P "(^@|NH:i:1)" | samtools view -Shb - > $@.part # PF, mapped, primary, unique; keep pcr duplicates
	mv $@.part $@
	~/tools/samtools-0.1.19/samtools index $@

.PHONY: clean-gsnap
clean-gsnap:
	rm gsnap/*
	rmdir gsnap