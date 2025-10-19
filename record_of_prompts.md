# Record of Significant Prompts to AI coding assistant


### phase 2 redux

The current work needs improving to provide a more general and more powerful foundation before progressing beyond phase2.

The RLS implementing RBAC is good. The use of projects to group people to control access for researcher roles to samples associated with those projects is a good example. However, this might be enhanced by allowing roles for different functionality for some people within  particular projects. A similar idea might be used later for a lab providing particular services/workflows,  and/or access to storage locations/labware.

We need to look more generally for patterns to simplify the current schema yet make it more general and powerful. 
Consider donor-level, samples, reagents, data-products - all should be part of the same provenance graph.
Samples' relationship to labware is similar to reagents to inventory. 
Both samples and reagents may have recommended treatment/storage recommendations and expected/recommended lifetimes.
Both may need to have their labware/inventory tracked including their storage locations, and chain of custody history. Data products have, potentially mulitple, data storage locations.

Starting with the concept of sample is that it is broadly something of fairly fixed nature. Processing it in some way creates another sample. Different samples can be produced from one sample e.g. splitting a DNA sample into smaller and larger fragment sizes. A sample can be produced from mulitple samples e.g. pooled sequencing library from indexed sequencing libraries. So..., aliquots (a subset of the sample where the samples nature is that splitting it produces separation of the same "thing") are best represented as the same "sample" in different labware. Some samples, e.g. whole insects, are atomic in nature i.e. you cannot take some  fraction of it without changing its nature. Other samples can be devided yet retains their nature as the same sample e.g. blood.

So, some samples may not have a container, certainly a donor especially a human one with not have container! Similarly, although many reagents will be in a container e.g. NaOH, some may not benefit from having a separate associated container e.g. a kit for sequencing run.

Then also consider donor-level, samples, reagents, data-products - all should be part of the same provenance graph.
Samples' relationship to labware is similar to reagents to inventory. 
Both samples and reagents may have recommended treatment/storage recommendations and expected/recommended lifetimes.
Both may need to have their labware/inventory tracked including their storage locations, and chain of custody history. Data products have, potentially mulitple, data storage locations.

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

### latent/multiplexed connections in provenance graph

In some circumstances where multiple samples e.g. "indexed libraries" are merged say to a single sample e.g. "pooled library", then processed to produce multiple data products, those should each be connected back to particular indexed library samples i.e. the intermediate squashing of multiple samples to one is actually "multiplexing" the provenance and that is de-multiplexed when creating the data products.

How can we represent that in the provenance graph/structures?

####

Note the tag sequence really is a property of the "indexed library" sample.

We can consider other variants on these "latent" direct links e.g. single cell data pooled from multiple donors for cost efficiency reasons and a later informatics process teases apart the data by genotyping the reads normally just used for expression, perhaps using genotyping info from an external source for the donors, or from a parallel exome workflow.

####

these additions sound too specific - the ability to map downstream nodes to matching (via some process specific means) to upstream nodes, where the intermediate lab process squash the numbers down to fewer or one intermediate sample (like a pool).


### test with DNA normalisation

To test the new (phase 2 redux) artefact and provenance data schema I'd like to flesh out a detailed example. Let's do normalisation of a plate of size fragmented and selected DNA:
- plate is composed of 1 negative control (water), 1 positive control (commercially bought DNA of given fragment size and concentration), 94 other wells containing the (size fragmented and selected DNA for the) scientific samples of interest
- so we have 96 sample-like artefacts, or perhaps 94 sample-like artefacts and  the 2 controls are reagent-like artefacts, all in a container/plate artefact at particular locations in that plate
- the concentration, and fragment size distribution, are  (initially unknown) properties of the sample-like artefacts, and known/expected properties of the control artefacts
- volume of these is a (currently unknown) property of the plate location where (at least some of) the sample-like artefact exists
- let's suppose the plate undergoes a "measurement" process using some "super-DNA-quantifier" instrument which leaves the plate and its contents unchanged, but returns a data_product, a file which can be parsed, containing the volume, DNA concentration, and DNA fragment distribution information for each well in that plate
- the LIMS system could/should update properties of artefacts it is tracking by parsing that data product 
- the volume information is best provided as a property of the well in the plate
- the DNA concentration and size distribution perhaps belong as an (updated) property of the sample-like artefacts (if the same sample-like artefact is in another plate as well, how might we deal with conflicting information? Just record both? Or, if this happens, acknowledge they are in fact now different sample artefacts and splice in extra nodes and edges to represent this?)
- there may be a lab QC step at this point to decide which sample are viable/useful - a pass/fail decision should be marked, probably on the sample-artefact
- the next "normalisation" process will try to produce a plate with equal volumes and equal DNA concentrations in each well (except the negative control)
- the LIMS generates a normalising manifest, with together with the above plate, a new empty plate and some buffer reagent, form the inputs to the process performed by a liquid handling robot which outputs a data product describing what it has done, and the input plate with reduced volumes, and the new plate now filled with the equal volume and equal concentration wells.
- the LIMS should create new sample artefacts in the new plate artefact, and adjust the properties of the input plate to account for the volumes used (as described in the robot's data product)

Having played out such an example, do we now think the separation of sample from the more physical labware excessive abstraction and without real value? Perhaps such separation of concept and physical should be based on sources of information, for example artefacts represent the fine-grained container and its contents (so well location, volume, concentrations, fragment size distributions).

Can we further simplify the data schema - get rid of the artefact_container_assignments table - such data should go on the well artefact.

In this revised data model, a physical sample is not (normally?) an artefact divorced from its container - as such we no longer have the situation of a sample being in different containers. Also the problem of conflicting measurement of a sample in two separate containers goes away as that would be two separate samples in this new model.
Please revise the documents accordingly.

There might still be a need for "virtual" (abstract or imported information) artefacts vs "physical" (in a well, or tube) and "container" (a plate) e.g. information on samples received from elsewhere such a identifiers and characteristics (gender/reference to genotyping) would be on a virtual artefact/sample, which would be linked to a physical artefact/sample on physical sample reception by a lab. Data products would either contain the data themselves (actual data product), or if large a description of the (virtual) data product (e.g. file names and relative paths, checksums, sizes) off which might hang data product locations which help track the data product lifecycle.

#### changing contents!

How can we deal with the contents of some container e.g. tube or well in a plate, changing through some process? e.g. DNA fragmentation using sonication, or adding an enzyme? Another example: a tube contains blood sample, this is spun down - the nature of the contents has changed, but the container is the same, and it was  input and output to this centrifuge process though the contents input have changed type to contents output.

### work in codex environment

Consider how this repo is designed for developer use either in a devcontainer (using docker outside of docker to allow docker compose to work with it), or using docker compose from outside a container.

I understand codex environments, such as the one you are running in, cannot use containers/docker, so please adapt  this repo to work without containers (so perhaps enabling a postgresql, postgrest and postgraphile services ) in codex environments so that the setup/migrations and tests can be run. It should still work in that same manner as now with docker compose both inside and outside a devcontainer as well.


### enhance ui

The web ui needs a little love.

The labware and storage explorer will not allow reset of focus or manual changing of the selections.

Can we put the different sections in different pages/routes, maybe with a section section on the left? Also, we need to cope gracefully with a large number of records, so provide pagination over a certain number.


### re consider the access control

Before moving on beyond phase2, (for the CrazyLIMS project), we need to reconsider requirements and options for the security and role model. The use of roles and RLS is good. But may not currently meet our future requirements.

We need to consider that access to data and processes is likely to be dictated by the studies/projects/(groups of samples) and the people/accounts allowed access to them.

For  a study, there may be  people who only enter/write virtual entities, and others, who doing work in the lab, will need to enter/write info for labware and processes undertaken ( after  an input plate registration marking the virtual entities as ancestors to the physical samples in the wells). Some people may be in both sets of people. For an all-in-one research lab, typical user of the ELN functionality, everyone in that study is likely to need to read all the data associated with it.

There may also be situations where a study has a set of people (research team) who are able to see all the virtual entity information and samples associated with them, but the lab processing is done by another set of people (production service lab) who should not be able to see the upstream  virtual entity, but who need to create/write the processes and samples/entities created downstream. The research team should be able to read all of the information for samples downstream of theirs (but not write in the places the service lab work).

Instruments and their automations will only be able read and update the samples/entities and processes local to their part of the provenance structure.

What options do we have for access control?

#### handover between groups/projects

We need to consider handover between teams/groups of people more explicitly I think. Also, the observability  and confidentiality though a multiplexing process in an operations lab for multiple research labs.

Let's consider two research studies (with different teams of people) and an operations lab.

Research lab working on project Alpha:
- Roberto (non lab researcher) registers samples (virtual entities) with project "alpha", donor id, donor age, region collected and donor gender for some blood samples
- Phillipa (researcher) received a plate "P202" with a manifest listing plate positions and donor ids for project "alpha", registers in LIMS linking with the prior "ancestor virtual samples"
- Phillipa processes plate to DNA fragmented to 400bp size in plate "D203"
- Ross (lab assistant) processes plate "D203" to indexed sequencing libraries in plate "L204" where the samples here are annotated with the i5 and i7 sequence tags
- Ross delivers plate "L203" to operations lab  (so in the LIMS, perhaps generating a new version of the plate in LIMS owned by operations where ids and key data like expected fragment size and sequence tags are visible, leaving a copy with "transferred" states owned by the research lab )

Second research lab working project Beta:
- Eric (non lab researcher) registers samples (virtual entities) with project "alpha", tube barcodes, donor id, donor age, region collected and donor gender for some blood samples

Operations Lab
- receive 270 tubes with blood samples for project "alpha"
- Lucy loads blood to seq library automation machine with tubes, outputs 3 plates L401, L402 and L403
- Fred quantifies plates L203, L401, L402 and L403, and creates normalised versions N203, N401, N402 and N403
- Fred pools N203, N401, N402 and N403 to library pool in tube LT5
- Fred  loads sequencing instrument with LT5 and appropriate manifest (created from ancestor tag sequence information)
- sequencing instrument output is processed by manifest to produce 366 data products which are linked, as well as back to LT5 via sequencing process but to upstream to wells in normalised indexed sequencing library plates  N203, N401, N402 and N403
- data product references in LIMS are copied/marked as transferred back to research labs

Required Visibility:
- the lab staff should be able to see all info on samples received in their lab, but not upstream info done in the research labs, nor downstream done after artefacts are  handed back to the research labs.
- the research labs should be able to see all info on artefacts in their studies, the artefacts in the operations lab derived from theirs and the associated processes, but not the data corresponding to the other lab's research project even if it is the same  library pool used for sequencing.

##### 

Re 1 - duplication of entities with minimal appropriate transfer of metadata is okay, so long there is a mechanism for propagating corrections. there should still be a chain of providence from "transferred" state originating lab artefacts to downstream duplicate artefacts.

Re 2 - if duplication with minimal appropriate metadata is done then this it moot, no?

Re 3 - yes, it is essential each research team only see data products that trace back to their project's samples — even if those were pooled together samples from other projects from other research teams

Re 4 - PostgreSQL and RLS as the enforcement point for these policies is the preferred boundary

##### get a plan

As an expert architect provide, in MarkDown format suitable for inclusion in the repo, a detailed plan for expert developers to implement for the implementation of these clarified security requirements.

This should include 
- a concise summary of the clarified security requirements
- an enumeration of the stories from which this has been created, so that they may be used for test cases
- the requirement that this logic should be implemented at the database level
- that the handover mechanism should be considered explicitly e.g. for a research group working on particular study to an operations lab for a standardised service on some of their samples and the return of that lab's output artefacts (physical or data products) to the research group/study
- the mechanism for doing this offered in the options in our conversation, consistent with the items immediately above in this list.

##### execute plan

As an expert software developer who favours clarity through minimal architecture and reusing existing patterns in their solutions, review the security-access-control-plan-phase1-and-2-security-redux.md plan with a view to starting to implement it. Keep changes as small as possible (e.g. exploit existing provenance graph capability rather than adding new tables). Favour test driven development where pragmatic. Ensure good explanatory code  and test documentation, good test coverage, and that the tests pass, so that the reviewer's task is straightforward.


### studies/groups and operational lab

As an expert software developer who favours clarity through minimal architecture and reusing existing patterns in their solutions, review the use of studies/research-projects (especially as used in access control evaluation as linking people and samples/artefacts ), the operational lab functionality (where a study/project may handover samples/artefacts for processing to that lab to then have the outputs samples/data products returned to the study/research project later), and how there may in fact be multiple operational labs (whose data access should be separate), or research teams which can help out on part of another research team's work but not see all of the study concerned. Can we generalise research studies and operational labs together with generalising the handover processes/methods/utilities (with the ability to keep current data access guarantees)? We should be able to simplify our data model (hopefully seeing the schema size shrink slightly) whilst achieving more capability. Create comprehensive and documented tests for the generalised functionality as well as implementing it.

### Later


Consider enhancing the Makefile so it does not tear down the devcontainer it is running in, and that connections from rest or graphql services don't block a DB reset.

### no longer relevant

We should keep the information about the nature of "sample", but note that it is represented as part of more general artefact model.
