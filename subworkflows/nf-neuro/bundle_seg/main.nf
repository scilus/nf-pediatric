include { REGISTRATION_ANTS                 } from '../../../modules/nf-neuro/registration/ants/main'
include { BUNDLE_RECOGNIZE                  } from '../../../modules/nf-neuro/bundle/recognize/main'

def fetchAtlases(channel, cohort) {
    channel.map { folder ->
        def meta = [id: "BundleSegAtlas", cohort: cohort]
        def files = [
            file("${folder}/atlas-${cohort}/*T1w.nii.gz"),
            file("${folder}/atlas-${cohort}/config.json"),
            file("${folder}/atlas-${cohort}/atlas/")
        ]
        def flattenedFiles = files.flatten().findAll { it.exists() }
        [meta] + flattenedFiles
    }
}

workflow BUNDLE_SEG {

    take:
        ch_fa               // channel: [ val(meta), [ fa ] ]
        ch_tractogram       // channel: [ val(meta), [ tractogram ] ]

    main:

        ch_versions = Channel.empty()

        // ** Setting up Atlas reference channels. ** //
        if ( params.atlas_directory ) {
            atlas_anat = Channel.fromPath("$params.atlas_directory/atlas/mni_masked.nii.gz", checkIfExists: true, relative: true)
            atlas_config = Channel.fromPath("$params.atlas_directory/config/config_fss_1.json", checkIfExists: true, relative: true)
            atlas_average = Channel.fromPath("$params.atlas_directory/atlas/atlas/", checkIfExists: true, relative: true)

            ch_register = ch_fa
                .combine(atlas_anat)
                .map { it + [[]] }
        }
        else {
            ch_atlases_path = channel.fromPath("${projectDir}/assets/")
            ch_atlas_infant00 = fetchAtlases(ch_atlases_path, "Infant00")
            ch_atlas_infant03 = fetchAtlases(ch_atlases_path, "Infant03")
            ch_atlas_infant06 = fetchAtlases(ch_atlases_path, "Infant06")
            ch_atlas_infant12 = fetchAtlases(ch_atlases_path, "Infant12")
            ch_atlas_infant24 = fetchAtlases(ch_atlases_path, "Infant24")
            ch_atlas_children = fetchAtlases(ch_atlases_path, "Children")

            // ** Register the atlas to subject's space. Set up atlas file as moving image ** //
            // ** and subject anat as fixed image.                                         ** //
            ch_register =  ch_fa
                .combine(ch_atlas_infant00.map { it[1] })
                .combine(ch_atlas_infant03.map { it[1] })
                .combine(ch_atlas_infant06.map { it[1] })
                .combine(ch_atlas_infant12.map { it[1] })
                .combine(ch_atlas_infant24.map { it[1] })
                .combine(ch_atlas_children.map { it[1] })
                .branch{
                    infant00: it[0].age < 0.125 || it[0].age > 18
                        return [ it[0], it[1], it[2], [] ]
                    infant03: (it[0].age >= 0.125 && it[0].age < 0.375)
                        return [ it[0], it[1], it[3], [] ]
                    infant06: (it[0].age >= 0.375 && it[0].age < 0.75)
                        return [ it[0], it[1], it[4], [] ]
                    infant12: (it[0].age >= 0.75 && it[0].age < 1.5)
                        return [ it[0], it[1], it[5], [] ]
                    infant24: (it[0].age >= 1.5 && it[0].age < 3)
                        return [ it[0], it[1], it[6], [] ]
                    child: true
                        return [ it[0], it[1], it[7], [] ]
                }
            ch_register = ch_register.infant00
                .mix(ch_register.infant03)
                .mix(ch_register.infant06)
                .mix(ch_register.infant12)
                .mix(ch_register.infant24)
                .mix(ch_register.child)
        }

        REGISTRATION_ANTS ( ch_register )
        ch_versions = ch_versions.mix(REGISTRATION_ANTS.out.versions.first())

        // ** Perform bundle recognition and segmentation ** //
        // ** If an external atlas directory is provided, use that. Otherwise, ** //
        // ** use the included atlases. ** //
        if ( params.atlas_directory ) {
            ch_recognize_bundle = ch_tractogram
                .join(REGISTRATION_ANTS.out.affine)
                .combine(atlas_config)
                .combine(atlas_average)
        } else {
            ch_recognize_bundle = ch_tractogram
                .join(REGISTRATION_ANTS.out.affine)
                .combine(ch_atlas_infant00.map { it[2] }) // config
                .combine(ch_atlas_infant00.map { it[3] }) // atlas folder
                .combine(ch_atlas_infant03.map { it[2] })
                .combine(ch_atlas_infant03.map { it[3] })
                .combine(ch_atlas_infant06.map { it[2] })
                .combine(ch_atlas_infant06.map { it[3] })
                .combine(ch_atlas_infant12.map { it[2] })
                .combine(ch_atlas_infant12.map { it[3] })
                .combine(ch_atlas_infant24.map { it[2] })
                .combine(ch_atlas_infant24.map { it[3] })
                .combine(ch_atlas_children.map { it[2] })
                .combine(ch_atlas_children.map { it[3] })
                .branch {
                    infant00: it[0].age < 0.125 || it[0].age > 18
                        return [ it[0], it[1], it[2], it[3], it[4] ]
                    infant03: (it[0].age >= 0.125 && it[0].age < 0.375)
                        return [ it[0], it[1], it[2], it[5], it[6] ]
                    infant06: (it[0].age >= 0.375 && it[0].age < 0.75)
                        return [ it[0], it[1], it[2], it[7], it[8] ]
                    infant12: (it[0].age >= 0.75 && it[0].age < 1.5)
                        return [ it[0], it[1], it[2], it[9], it[10] ]
                    infant24: (it[0].age >= 1.5 && it[0].age < 3)
                        return [ it[0], it[1], it[2], it[11], it[12] ]
                    child: true
                        return [ it[0], it[1], it[2], it[13], it[14] ]
                }
            ch_recognize_bundle = ch_recognize_bundle.infant00
                .mix(ch_recognize_bundle.infant03)
                .mix(ch_recognize_bundle.infant06)
                .mix(ch_recognize_bundle.infant12)
                .mix(ch_recognize_bundle.infant24)
                .mix(ch_recognize_bundle.child)
        }

        BUNDLE_RECOGNIZE ( ch_recognize_bundle )
        ch_versions = ch_versions.mix(BUNDLE_RECOGNIZE.out.versions.first())


    emit:
        bundles = BUNDLE_RECOGNIZE.out.bundles              // channel: [ val(meta), [ bundles ] ]

        versions = ch_versions                              // channel: [ versions.yml ]
}
