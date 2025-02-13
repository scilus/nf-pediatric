workflow FETCH_DERIVATIVES {

    take:
    input_deriv

    main:
    //
    // Create channels from a derivatives folder (params.input_deriv)
    //

    // ** Segmentations ** //
    ch_labels = Channel.fromPath("${input_deriv}/sub-*/{ses-*/,}anat/*{,space-DWI}_seg*dseg.nii.gz",
        checkIfExists: true)
        .map{ file ->
            def parts = file.toAbsolutePath().toString().split('/')
            def id = parts.find { it.startsWith('sub-') }
            def session = parts.find { it.startsWith('ses-') }
            def metadata = session ? [id: id, session: session, run: "", age: ""] : [id: id, session: "", run: "", age: ""]

            return [metadata, file]
        }
        .groupTuple(by: 0)
        .map{ meta, files ->
            return [meta] + files
        }

    // ** Anatomical file ** //
    ch_anat = Channel.fromPath("${input_deriv}/sub-**/{ses-*/,}anat/*space-DWI_desc-preproc_{T1w,T2w}.nii.gz",
        checkIfExists: true)
        .map { file ->
            def parts = file.toAbsolutePath().toString().split('/')
            def id = parts.find { it.startsWith('sub-') }
            def session = parts.find { it.startsWith('ses-') }
            def metadata = session ? [id: id, session: session, run: "", age: ""] : [id: id, session: "", run: "", age: ""]

            return [metadata, file]
        }

    // ** Transformation files ** //
    ch_transforms = Channel.fromPath("${input_deriv}/sub-*/{ses-*/,}anat/*from-{T1w,T2w}_to-dwi_{warp,affine}*",
        checkIfExists: true)
        .map { file ->
            def parts = file.toAbsolutePath().toString().split('/')
            def id = parts.find { it.startsWith('sub-') }
            def session = parts.find { it.startsWith('ses-') }
            def meta = session ? [id: id, session: session, run: "", age: ""] : [id: id, session: "", run: "", age: ""]

            return [meta, file]
        }
        .groupTuple(by: 0)
        .map { meta, files ->
            if (files.size() == 2) {
                return [meta] + files
            } else {
                error "ERROR ~ Missing transformation files for ${meta.id}"
            }
        }

    // ** Peaks file ** //
    ch_peaks = Channel.fromPath("${input_deriv}/sub-*/{ses-*/,}dwi/*desc-peaks*",
        checkIfExists: true)
        .map { file ->
            def parts = file.toAbsolutePath().toString().split('/')
            def id = parts.find { it.startsWith('sub-') }
            def session = parts.find { it.startsWith('ses-') }
            def meta = session ? [id: id, session: session, run: "", age: ""] : [id: id, session: "", run: "", age: ""]

            return [meta, file]
        }

    // ** fODF file ** //
    ch_fodf = Channel.fromPath("${input_deriv}/sub-*/{ses-*/,}dwi/*desc-fodf*",
        checkIfExists: true)
        .map { file ->
            def parts = file.toAbsolutePath().toString().split('/')
            def id = parts.find { it.startsWith('sub-') }
            def session = parts.find { it.startsWith('ses-') }
            def meta = session ? [id: id, session: session, run: "", age: ""] : [id: id, session: "", run: "", age: ""]

            return [meta, file]
        }

    // ** DWI files (dwi, bval, bvec) ** //
    ch_dwi_bval_bvec = Channel.fromPath("${input_deriv}/sub-*/{ses-*/,}dwi/*desc-preproc_dwi.{nii.gz,bval,bvec}",
        checkIfExists: true)
        .map { file ->
            def parts = file.toAbsolutePath().toString().split('/')
            def id = parts.find { it.startsWith('sub-') }
            def session = parts.find { it.startsWith('ses-') }
            def meta = session ? [id: id, session: session, run: "", age: ""] : [id: id, session: "", run: "", age: ""]

            return [meta, file]
        }
        .groupTuple(by: 0)
        .map { meta, files ->
            if (files.size() == 3) {
                return [meta] + files
            } else {
                error "ERROR ~ Missing dwi/bval/bvec files for ${meta.id}"
            }
        }

    // ** Tractogram file ** //
    ch_trk = Channel.fromPath("${input_deriv}/sub-*/{ses-*/,}dwi/*desc-*_tracking.trk", checkIfExists: true)
        .map { file ->
            def parts = file.toAbsolutePath().toString().split("/")
            def id = parts.find { it.startsWith('sub-') }
            def session = parts.find { it.startsWith('ses-') }
            def meta = session ? [id: id, session: session, run: "", age: ""] : [id: id, session: "", run: "", age: ""]

            return [meta, file]
        }

    // ** Metrics files ** //
    ch_metrics = Channel.fromPath("${input_deriv}/sub-*/{ses-*/,}dwi/*desc-{fa,md,rd,ad,nufo,afd_total,afd_sum,afd_max}.nii.gz",
        checkIfExists: true)
        .map { file ->
            def parts = file.toAbsolutePath().toString().split("/")
            def id = parts.find { it.startsWith('sub-') }
            def session = parts.find { it.startsWith('ses-') }
            def meta = session ? [id: id, session: session, run: "", age: ""] : [id: id, session: "", run: "", age: ""]

            return [meta, file]
        }
        .groupTuple(by: 0)
        .map{ meta, files ->
            return [meta] + [files]
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

