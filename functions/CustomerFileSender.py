# -------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for
# license information.
# --------------------------------------------------------------------------

import logging

import azure.functions as func
import os

from azure.storage.blob import BlobClient
from Cryptodome import Random
from Cryptodome.Cipher import AES

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    file_name = req.params.get('filename')
    if not file_name:
        try:
            req_body = req.get_json()
        except ValueError:
            pass
        else:
            file_name = req_body.get('filename')

    if file_name:
       key = b'\xbf\xc0\x85)\x10nc\x94\x02)j\xdf\xcb\xc4\x94\x9d(\x9e[EX\xc8\xd5\xbfI{\xa2$\x05(\xd5\x18'
       file_name_enc = encrypt_send_file(file_name, key)
       return func.HttpResponse(file_name + " has been encrypyted as " + file_name_enc +" and sent to Azure account Blob successfully.")
    else:
        return func.HttpResponse(
             "Looking for filename.... Pass a query string ( ?filename=file.ext ) to send customer file to Azure Blob",
             status_code=200
        )

def encrypt_send_file(file_name, key) ->str:
    with open(file_name, 'rb') as fo:
        plaintext = fo.read()
    enc = encrypt(plaintext, key)
    file_name_enc = file_name + ".enc"
    with open(file_name_enc, 'wb') as fo:
        fo.write(enc)
    
    conn_string = os.environ["AZURE_STORAGE_CONNECTION_STRING"]
       
    blob_client = BlobClient.from_connection_string(conn_string,
    container_name="compdev-customer-storage-container", blob_name=file_name_enc)

    # Open a local file and upload its contents to Blob Storage
    with open(file_name_enc, "rb") as data:
        blob_client.upload_blob(data, 
        blob_type='BlockBlob')
    return file_name_enc

def pad(s):
    return s + b"\0" * (AES.block_size - len(s) % AES.block_size)

def encrypt(message, key, key_size=256):
    message = pad(message)
    iv = Random.new().read(AES.block_size)
    cipher = AES.new(key, AES.MODE_CBC, iv)
    return iv + cipher.encrypt(message)