include { REGISTRATION_ANTS                 } from '../../../modules/nf-neuro/registration/ants/main'
include { BUNDLE_RECOGNIZE                  } from '../../../modules/nf-neuro/bundle/recognize/main'

def fetch_bundleseg_atlas(atlasUrl, configUrl, dest) {

    def atlas = new File("$dest/atlas.zip").withOutputStream { out ->
        new URL(atlasUrl).withInputStream { from -> out << from; }
    }

    def config = new File("$dest/config.zip").withOutputStream { out ->
        new URL(configUrl).withInputStream { from -> out << from; }
    }

    def atlasFile = new java.util.zip.ZipFile("$dest/atlas.zip")
    atlasFile.entries().each { it ->
        def path = java.nio.file.Paths.get("$dest/atlas/" + it.name)
        if(it.directory){
            java.nio.file.Files.createDirectories(path)
        }
        else {
            def parentDir = path.getParent()
            if (!java.nio.file.Files.exists(parentDir)) {
                java.nio.file.Files.createDirectories(parentDir)
            }
            java.nio.file.Files.copy(atlasFile.getInputStream(it), path)
        }
    }

    def configFile = new java.util.zip.ZipFile("$dest/config.zip")
    configFile.entries().each { it ->
        def path = java.nio.file.Paths.get("$dest/config/" + it.name)
        if(it.directory){
            java.nio.file.Files.createDirectories(path)
        }
        else {
            def parentDir = path.getParent()
            if (!java.nio.file.Files.exists(parentDir)) {
                java.nio.file.Files.createDirectories(parentDir)
            }
            java.nio.file.Files.copy(configFile.getInputStream(it), path)
        }
    }
}

workflow BUNDLE_SEG {

    take:
        ch_fa               // channel: [ val(meta), [ fa ] ]
        ch_tractogram       // channel: [ val(meta), [ tractogram ] ]

    main:

        ch_versions = Channel.empty()

        // ** Setting up Atlas reference channels. ** //
        atlas_infant_t2w = Channel.fromPath("$projectDir/assets/atlas-Neonates/tpl-UNCBCP4DInfant_cohort-00_desc-brain_T2w.nii.gz", checkIfExists: true, relative: true)
        atlas_infant_config = Channel.fromPath("$projectDir/assets/atlas-Neonates/config_infant.json", checkIfExists: true, relative: true)
        atlas_infant_average = Channel.fromPath("$projectDir/assets/atlas-Neonates/atlas/", checkIfExists: true, relative: true)

        if ( params.atlas_directory ) {
            atlas_anat = Channel.fromPath("$params.atlas_directory/atlas/mni_masked.nii.gz", checkIfExists: true, relative: true)
            atlas_config = Channel.fromPath("$params.atlas_directory/config/config_fss_1.json", checkIfExists: true, relative: true)
            atlas_average = Channel.fromPath("$params.atlas_directory/atlas/atlas/", checkIfExists: true, relative: true)
        }
        else {
            if ( !file("$workflow.workDir/atlas/mni_masked.nii.gz").exists() ) {
            fetch_bundleseg_atlas(  "https://zenodo.org/records/10103446/files/atlas.zip?download=1",
                                    "https://zenodo.org/records/10103446/files/config.zip?download=1",
                                    "${workflow.workDir}/")
            }
            atlas_anat = Channel.fromPath("$workflow.workDir/atlas/mni_masked.nii.gz")
            atlas_config = Channel.fromPath("$workflow.workDir/config/config_fss_1.json")
            atlas_average = Channel.fromPath("$workflow.workDir/atlas/atlas/")
        }

        // ** Register the atlas to subject's space. Set up atlas file as moving image ** //
        // ** and subject anat as fixed image.                                         ** //
        ch_register =  ch_fa
            .combine(atlas_infant_t2w)
            .combine(atlas_anat)
            .branch{
                infant: it[0].age < 0.5 || it[0].age > 18
                    return [ it[0], it[1], it[2], [] ]
                child: true
                    return [ it[0], it[1], it[3], [] ]
            }
        ch_register = ch_register.infant.mix(ch_register.child)

        REGISTRATION_ANTS ( ch_register )
        ch_versions = ch_versions.mix(REGISTRATION_ANTS.out.versions.first())

        // ** Perform bundle recognition and segmentation ** //
        ch_recognize_bundle = ch_tractogram
            .join(REGISTRATION_ANTS.out.affine)
            .combine(atlas_infant_config)
            .combine(atlas_infant_average)
            .combine(atlas_config)
            .combine(atlas_average)
            .branch {
                infant: it[0].age < 0.5 || it[0].age > 18
                    return [ it[0], it[1], it[2], it[3], it[4] ]
                child: true
                    return [ it[0], it[1], it[2], it[5], it[6] ]
            }
        ch_recognize_bundle = ch_recognize_bundle.infant.mix(ch_recognize_bundle.child)

        BUNDLE_RECOGNIZE ( ch_recognize_bundle )
        ch_versions = ch_versions.mix(BUNDLE_RECOGNIZE.out.versions.first())


    emit:
        bundles = BUNDLE_RECOGNIZE.out.bundles              // channel: [ val(meta), [ bundles ] ]

        versions = ch_versions                              // channel: [ versions.yml ]
}
