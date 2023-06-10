# -- Create (if needed) GCS bucket for Terraform states corresponding to the non-breaking tf configuration -- # 

created=$(gsutil ls -p r-server-326920 | grep r-server-326920-tf-states-nb-1 | wc -l)
if [ ${created} == 0 ]; then
    echo "Bucket does not exist"
    echo "Creating GCS state bucket for non-breaking tf configuration..."
    gsutil mb -p r-server-326920 -c regional -l europe-west4 gs://r-server-326920-tf-states-nb-1
else
    echo "Bucket exists, nothing else to check.."
fi

