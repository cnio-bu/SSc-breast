import glob

## TODO: This rule can be split in 2
checkpoint prism_annotate_models:
    input:
        response_curves=datasets.loc["prism_response_curves", "directory"],
        cell_lines_annotation=rules.annotate_cell_lines.output.cell_lines_annotation,
        count_matrix=rules.get_rnaseq_counts.output.raw_gene_counts,
    output:
        auc_models_candidates=directory(f"{results}/prism/auc_models_candidates"),
        compounds_lines_profiled=f"{results}/prism/compounds_lines_profiled.csv",
    threads: get_resource("ctrp_annotate_models", "threads"),
    resources:
        mem=get_resource("ctrp_annotate_models", "mem"),
        walltime=get_resource("ctrp_annotate_models", "walltime"),
    conda:
        "../envs/common_file_manipulation.yaml"
    script:
        "../scripts/prism_generate_annotation.R"


rule prism_compounds_diffexpr:
    input:
        raw_gene_counts=rules.get_rnaseq_counts.output.raw_gene_counts,
        compound_to_test=f"{results}/prism/auc_models_candidates/{{broad_id}}.csv",
    output:
        ebayes=f"{results}/prism/ebayes/{{broad_id}}_eBayes.rds",
    log:
        f"{LOGDIR}/prism_compounds_diffexpr/{{broad_id}}.log",
    threads: get_resource("gdsc_compounds_diffexp", "threads"),
    resources:
        mem=get_resource("gdsc_compounds_diffexp", "mem"),
        walltime=get_resource("gdsc_compounds_diffexp", "walltime"),
    conda:
        "../envs/prism_limma.yaml"
    script:
        "../scripts/prism_generate_ebayes_model.R"


rule prism_build_db:
    input:
        compound_data=glob.glob(f"{results}/prism/auc_models_candidates/*.csv"),
        lines_compounds=rules.prism_annotate_models.output.compounds_lines_profiled,
    output:
        csv_db=f"{results}/prism/drug_data.csv",
        rdata_db=f"{results}/prism/drug_data.rdata",
    log:
        f"{LOGDIR}/prism_build_db/log.txt",
    threads: get_resource("annotate_cell_lines", "threads"),
    resources:
        mem=get_resource("annotate_cell_lines", "mem"),
        walltime=get_resource("annotate_cell_lines", "walltime"),
    conda:
        "../envs/common_file_manipulation.yaml"
    script:
        "../scripts/prism_generate_drug_db.R"


##TODO: These two rules could benefit from rule inheritance
rule prism_geneset_from_ebayes_classic:
    input:
        fitted_bayes=rules.prism_compounds_diffexpr.output.ebayes,
        treatment_info=datasets.loc["prism_treatment_info", "directory"],
    output:
        bidirectional_geneset=directory(
            f"{results}/prism/genesets/classic/{{broad_id}}"
        ),
    log:
        f"{LOGDIR}/prism_geneset_from_ebayes/{{broad_id}}_classic.log",
    params:
        signature_type="classic",
    threads: get_resource("ctrp_generate_geneset", "threads"),
    resources:
        mem=get_resource("ctrp_generate_geneset", "mem"),
        walltime=get_resource("ctrp_generate_geneset", "walltime"),
    conda:
        "../envs/generate_genesets.yaml"
    script:
        "../scripts/prism_signature_from_ebayes.R"


rule prism_geneset_from_ebayes_fold:
    input:
        fitted_bayes=rules.prism_compounds_diffexpr.output.ebayes,
        treatment_info=datasets.loc["prism_treatment_info", "directory"],
    output:
        bidirectional_geneset=directory(f"{results}/prism/genesets/fold/{{broad_id}}"),
    log:
        f"{LOGDIR}/prism_geneset_from_ebayes/{{broad_id}}_fold.log",
    params:
        signature_type="fold",
    threads: get_resource("ctrp_generate_geneset", "threads"),
    resources:
        mem=get_resource("ctrp_generate_geneset", "mem"),
        walltime=get_resource("ctrp_generate_geneset", "walltime"),
    conda:
        "../envs/generate_genesets.yaml"
    script:
        "../scripts/prism_signature_from_ebayes.R"