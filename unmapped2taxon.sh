~/tools/samtools-0.1.19/samtools view -f 4 -s 22.01 ~/chrisi/results/gsnap/test.gsnap.bam | head -1000 | awk '{OFS="\t"; print ">"$1"\n"$10}' - | BLASTDB=~/tools/ncbi-blast-2.2.29+/db ~/tools/ncbi-blast-2.2.29+/bin/blastn -task megablast -db nt -query /dev/stdin -remote -outfmt "7 qacc sacc length pident staxids sscinames scomnames sskingdoms" | tee ~/chrisi/results/blast/test.unmapped-reads.blast.out | grep -vP "^#" | cut -f 1,5,6,7,8 | sort | uniq | cut -f 2,3,4,5 | sort | uniq -c | sort -k 1,1nr > ~/chrisi/results/blast/test.unmapped-reads.species-hits.tsv
