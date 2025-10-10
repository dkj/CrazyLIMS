# Record of Significant Prompts to AI coding assistant


### phase 2 redux

The current work needs improving to provide a more general and more powerful foundation before progressing beyond phase2.

The RLS implementing RBAC is good. The use of projects to group people to control access for researcher roles to samples associated with those projects is a good example. However, this might be enhanced by allowing roles for different functionality for some people within  particular projects. A similar idea might be used later for a lab providing particular services/workflows,  and/or access to storage locations/labware.

We need to look more generally for patterns to simplify the current schema yet make it more general and powerful. 
Consider donor-level, samples, reagents, data-products - all should be part of the same provenance graph.
Samples' relationship to labware is similar to reagents to inventory. 
Both samples and reagents may have recommended treatment/storage recommendations and expected/recommended lifetimes.
Both may need to have their labware/inventory tracked including their storage locations, and chain of custody histroy. Data products have, potentially mulitple, data storage locations.

Starting with the concept of sample is that it is broadly something of fairly fixed nature. Processing it in some way creates another sample. Different samples can be produced from one sample e.g. splitting a DNA sample into smaller and larger fragment sizes. A sample can be produced from mulitple samples e.g. pooled sequencing library from indexed sequencing libraries. So..., aliquots (a subset of the sample where the samples nature is that splitting it produces separation of the same "thing") are best represented as the same "sample" in different labware. Some samples, e.g. whole insects, are atomic in nature i.e. you cannot take some  fraction of it without changing its nature. Other samples can be devided yet retains their nature as the same sample e.g. blood.

So, some samples may not have a container, certainly a donor especially a human one with not have container! Similarly, although many reagents will be in a container e.g. NaOH, some may not benefit from having a separate associated container e.g. a kit for sequencing run.

Then also consider donor-level, samples, reagents, data-products - all should be part of the same provenance graph.
Samples' relationship to labware is similar to reagents to inventory. 
Both samples and reagents may have recommended treatment/storage recommendations and expected/recommended lifetimes.
Both may need to have their labware/inventory tracked including their storage locations, and chain of custody histroy. Data products have, potentially mulitple, data storage locations.

The connections in the provenance graphs will need to (optionally) connect to the processes which may come from an ELN or more formalised workflow.

Example provenance graph: 
from insects in a plate (samples) -> image captures per well (data product)
from insects in a 32 well plates (samples), 3 at a time used for ->  DNA extraction in 96 well  plates (samples, type DNA raw) -> cytochrome amplicon creation in 96 well plates (samples, type DNA amplicon), 4 used for -> longread indexed PacBio library creation in  384-well plate (samples, type indexed pacbio sequencing library ), 10 used -> pooling in one tube (sample, type pooled) -> PacBio sequencing process -> sequence data unaligned Pacbio bam file (data product, bam file and auxilary files) -> custom indexed library deplexing informatics process to "per sample" data (32 * 3 * 4 *10 = 3840) (data product, bam files) 

Another example:
500000 humans (donors) -> each sampled for blood in tube (sample, type blood) and nasal swab in tube (sample, type swab) -> separate tracks each have DNA extraction say 94 tubes at a time, and a negative contols water, and a positive control (reagent, combo commercial human dna, or some viral DNA fragment combo test set )  -> 96 well  plates (sample, DNA raw), then plates split to continue processing and long term storage
Continued progress for swab path via a bait selection process (sample, DNA), indexed library creation 384 well plates (sample type index sequencelibrary), pooling to tube (sample, type pooled sequencing library), 8 tube to 8 lane Illumina sequencing flowcell, Illumina sequencing -> 8*384 sequence data per sample (data product, type cram files) -> custom viral and metagenomics pipelines (data products, type custom fileset) 
Continue progress for blood path via fragmentation, selection (sample, DNA  ) and then quantification (data product) -> data with input dna,  for normalised indexed library creation in 96 well plates (sample, type indexed seq library)-> pooled library 1 tube (sample, type pooled seq library) -> whole flowcell Illumina sequencing to data per samlpe (data product, aligned CRAM files and gVCF variant calls) -> combined with cohort variant QC for research ready access (data product, custom Hail ready dataset)

Find  more examples to add to your consideration. Then try to create the simplified, but more general model, from which we can still present interfaces convenient and useful to the researchers and lab staff e.g. by sample, or by reagent, stock invetories, what is in a freezer, chain-of-cusotdy for sample from donor donation through to research ready data products.

#### 

Do containers belong in the provenance hierarchy, or are they better being represnted separately but perhaps connected to the elements of the provence hierarchy, and the processes which form the edges in the provence hierarchy?

####

Ok make a detailed Phase 2 Redux detailed plan and record it in a markdown file like the others.


### phase 1 redux

Let's also reconsier the phase1 work: the preparedness for audit log and RLS for RBAC works well. Should we consider that changes to data in the system should only be done in transactions, and that those transactions should correspond to an end user, taking on particular role (or multiple?), via a particular access role e.g. one for postgrest. As such is it worth recording all that info of transaction time, user, roles of various kinds, in a table and referencing that in any rows inserted, updated, or deleted, and  in the audit table too (something explicit to track deletion properly).

####
ok turn this into a phase 1 redux plan in a markdown file.

### plan redux work 

Given the phase 1 redux and phase 2 redux plans, should we start the project again with new a new database? Or try to alter the existing one.

####

There is no production system yet, so there is no real operational data, only data we've created for testing the system. I am concerned about vestigal elements of the early design adversly affecting the new one we've created given our earlier experience

### latent/multiplexed connections in provenence graph

In some circumstances where mulitple samples e.g. "indexed libaries" are merged say to a single sample e.g. "pooled library", then processed to produce multiple data products, those should each be connected back to particular indexed library samples i.e. the intermediate squashing of mulitple samples to one is actually "mulitplexing" the provenance and that is de-multiplexed when creating the data products.

How can we represent that in the provenance graph/structures?

####

Note the tag sequence really is a property of the "indexed library" sample.

We can consider other variants on these "latent" direct links e.g. single cell data pooled from multiple donors for cost efficiency reasons and a later informtics process teases apart the data by genotyping the reads normally just used for expression, perhaps using genotyping info from an external source for the donors, or from a parallel exome workflow.

####

these addtions sound too specific - the ability to map downstream nodes to matching (via some process specific means) to upstream nodes, where the intermediate lab process squash the numbers down to fewer or one intermediate sample (like a pool).


### Later

Consider enhancing the Makefile so it does not tear down the devcontainer it is running in, and that connections from rest or graphql services don't block a DB reset.
