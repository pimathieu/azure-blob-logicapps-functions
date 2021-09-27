# -------------------------------------------------------------------------
# Pierre Mathieu. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for
# license information.
# --------------------------------------------------------------------------


import logging
import os
import azure.functions as func

from azure.storage.blob import BlobServiceClient, generate_account_sas, ResourceTypes, AccountSasPermissions
from datetime import datetime, timedelta

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    enckey = req.params.get('enckey')
    if not enckey:
        try:
            req_body = req.get_json()
        except ValueError:
            pass
        else:
            enckey = req_body.get('enckey')

    if enckey:
        try:
            sas_token = generate_account_sas(
            account_name=os.environ["ACCOUNT_NAME"],
            account_key=os.environ["ACCOUNT_KEY"],
            resource_types=ResourceTypes(service=True),
            permission=AccountSasPermissions(read=True),
            expiry=datetime.utcnow() + timedelta(minutes=1)
            )
        except ValueError:
            pass
            
        if sas_token:
            return func.HttpResponse(sas_token)
        else:
            return func.HttpResponse(
                "This HTTP triggered function executed successfully. Pass a name in the query string or in the request body for a personalized response.",
                status_code=200
            )
    else:
        return func.HttpResponse(
             "No Encryption key foun",
             status_code=200
        )