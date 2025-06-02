def readParticipantsTsv(file) {
    def participantMap = [:]

    file.splitCsv(sep: '\t', header: true).each { row ->
        // Access columns by name regardless of position
        if ( ! row.age ) {
            error "ERROR: Age is not entered correctly in the participants.tsv file. Please validate."
        }
        participantMap[row.participant_id] = row.age.toFloat()
    }

    return participantMap
}

workflow FETCH_DERIVATIVES {

    take:
    input_deriv

    main:
    //
    // Create channels from a derivatives folder (params.input_deriv)
    //
    if ( ! file("${input_deriv}/participants.tsv").exists() ) {
        error "ERROR: Your bids dataset does not contain a participants.tsv file. " +
        "Please provide a participants.tsv file with a column indicating the participants' " +
        "age. For any questions, please refer to the documentation at " +
        "https://github.com/scilus/nf-pediatric.git or open an issue!"
    }

    participantsTsv = file("${input_deriv}/participants.tsv")
    ageMap = readParticipantsTsv(participantsTsv)
    def participant_ids = params.participant_label ?: []

    // Helper function to get age
    def getAge = { id ->
        return ageMap[id] ?: ""
    }

    // ** Segmentations ** //
    ch_labels = Channel.fromPath("${input_deriv}/sub-*/{ses-*/,}anat/*{,space-DWI}_seg*dseg.nii.gz",
        checkIfExists: true)
        .map{ file ->
            def parts = file.toAbsolutePath().toString().split('/')
            def id = parts.find { it.startsWith('sub-') }
            def session = parts.find { it.startsWith('ses-') }
            def age = getAge(id)
            def metadata = session ? [id: id, session: session, run: "", age: age] : [id: id, session: "", run: "", age: age]

            return [metadata, file]
        }
        .groupTuple(by: 0)
        .map{ meta, files ->
            return [meta] + files
        }
        .filter {
            participant_ids.isEmpty() || it[0].id in participant_ids
        }

    // ** Anatomical file ** //
    ch_anat = Channel.fromPath("${input_deriv}/sub-**/{ses-*/,}anat/*space-DWI_desc-preproc_{T1w,T2w}.nii.gz",
        checkIfExists: true)
        .map { file ->
            def parts = file.toAbsolutePath().toString().split('/')
            def id = parts.find { it.startsWith('sub-') }
            def session = parts.find { it.startsWith('ses-') }
            def age = getAge(id)
            def metadata = session ? [id: id, session: session, run: "", age: age] : [id: id, session: "", run: "", age: age]
            def type = file.name.contains('T1w') ? 'T1w' : 'T2w'

            return [metadata, type, file]
        }
        .groupTuple(by: 0)
        .map{ metadata, types, files ->
            def sortedFiles = [types, files].transpose().sort { it[0] }.collect { it[1] }
            return [metadata] + sortedFiles
        }
        .filter {
            participant_ids.isEmpty() || it[0].id in participant_ids
        }

    // ** Transformation files ** //
    ch_transforms = Channel.fromPath("${input_deriv}/sub-*/{ses-*/,}anat/*from-{T1w,T2w}_to-dwi_{warp,affine}*",
        checkIfExists: true)
        .map { file ->
            def parts = file.toAbsolutePath().toString().split('/')
            def id = parts.find { it.startsWith('sub-') }
            def session = parts.find { it.startsWith('ses-') }
            def age = getAge(id)
            def meta = session ? [id: id, session: session, run: "", age: age] : [id: id, session: "", run: "", age: age]
            def type = file.name.contains('warp') ? 'warp' : 'affine'

            return [meta, type, file]
        }
        .groupTuple(by: 0)
        .map { meta, types, files ->
            if (files.size() == 2) {
                def sortedFiles = [types, files].transpose().sort { a, b ->
                if (a[0] == 'warp') return -1
                if (b[0] == 'warp') return 1
                return 0
                }.collect { it[1] }
                return [meta] + sortedFiles
            } else {
                error "ERROR ~ Missing transformation files for ${meta.id}"
            }
        }
        .filter {
            participant_ids.isEmpty() || it[0].id in participant_ids
        }

    // ** Peaks file ** //
    ch_peaks = Channel.fromPath("${input_deriv}/sub-*/{ses-*/,}dwi/*desc-peaks*",
        checkIfExists: true)
        .map { file ->
            def parts = file.toAbsolutePath().toString().split('/')
            def id = parts.find { it.startsWith('sub-') }
            def session = parts.find { it.startsWith('ses-') }
            def age = getAge(id)
            def meta = session ? [id: id, session: session, run: "", age: age] : [id: id, session: "", run: "", age: age]

            return [meta, file]
        }

    // ** fODF file ** //
    ch_fodf = Channel.fromPath("${input_deriv}/sub-*/{ses-*/,}dwi/*desc-fodf*",
        checkIfExists: true)
        .map { file ->
            def parts = file.toAbsolutePath().toString().split('/')
            def id = parts.find { it.startsWith('sub-') }
            def session = parts.find { it.startsWith('ses-') }
            def age = getAge(id)
            def meta = session ? [id: id, session: session, run: "", age: age] : [id: id, session: "", run: "", age: age]

            return [meta, file]
        }
        .filter {
            participant_ids.isEmpty() || it[0].id in participant_ids
        }

    // ** DWI files (dwi, bval, bvec) ** //
    ch_dwi_bval_bvec = Channel.fromPath("${input_deriv}/sub-*/{ses-*/,}dwi/*desc-preproc_dwi.{nii.gz,bval,bvec}",
        checkIfExists: true)
        .map { file ->
            def parts = file.toAbsolutePath().toString().split('/')
            def id = parts.find { it.startsWith('sub-') }
            def session = parts.find { it.startsWith('ses-') }
            def age = getAge(id)
            def meta = session ? [id: id, session: session, run: "", age: age] : [id: id, session: "", run: "", age: age]

            return [meta, file]
        }
        .groupTuple(by: 0)
        .map { meta, files ->
            if (files.size() == 3) {
                def sortedFiles = files.sort { file ->
                    if (file.extension == "nii.gz") {
                        return 0
                    } else if (file.extension == "bval") {
                        return 1
                    } else if (file.extension == "bvec") {
                        return 2
                    }
                }
                return [meta] + sortedFiles
            } else {
                error "ERROR ~ Missing dwi/bval/bvec files for ${meta.id}"
            }
        }
        .filter {
            participant_ids.isEmpty() || it[0].id in participant_ids
        }

    // ** Tractogram file ** //
    ch_trk = Channel.fromPath("${input_deriv}/sub-*/{ses-*/,}dwi/*desc-*_tractogram.trk", checkIfExists: true)
        .map { file ->
            def parts = file.toAbsolutePath().toString().split("/")
            def id = parts.find { it.startsWith('sub-') }
            def session = parts.find { it.startsWith('ses-') }
            def age = getAge(id)
            def meta = session ? [id: id, session: session, run: "", age: age] : [id: id, session: "", run: "", age: age]

            return [meta, file]
        }
        .filter {
            participant_ids.isEmpty() || it[0].id in participant_ids
        }

    // ** Metrics files ** //
    ch_metrics = Channel.fromPath("${input_deriv}/sub-*/{ses-*/,}dwi/*desc-{fa,md,rd,ad,nufo,afd_total,afd_sum,afd_max}.nii.gz",
        checkIfExists: true)
        .map { file ->
            def parts = file.toAbsolutePath().toString().split("/")
            def id = parts.find { it.startsWith('sub-') }
            def session = parts.find { it.startsWith('ses-') }
            def age = getAge(id)
            def meta = session ? [id: id, session: session, run: "", age: age] : [id: id, session: "", run: "", age: age]

            return [meta, file]
        }
        .groupTuple(by: 0)
        .map{ meta, files ->
            return [meta] + [files]
        }
        .filter {
            participant_ids.isEmpty() || it[0].id in participant_ids
        }

    emit:
    anat            = ch_anat
    labels          = ch_labels
    transforms      = ch_transforms
    peaks           = ch_peaks
    fodf            = ch_fodf
    dwi_bval_bvec   = ch_dwi_bval_bvec
    trk             = ch_trk
    metrics         = ch_metrics
}

