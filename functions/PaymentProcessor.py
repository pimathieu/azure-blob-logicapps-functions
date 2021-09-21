# -------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for
# license information.
# --------------------------------------------------------------------------

import logging

import azure.functions as func
import os
import pandas as pd
from io import StringIO
import json
# Import the client object from the SDK library
from azure.storage.blob import BlobClient, ContainerClient
from Cryptodome.Cipher import AES

from azure.servicebus import ServiceBusClient, ServiceBusMessage

# Retrieve encryption key from key vault and decrypt file. Perform required submission. Save the decripted file. 
def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    apitoken =  os.environ['APP_TOKEN_VALUE']
    apitoken = "test-token"

    if not apitoken:
       return func.HttpResponse("No value found in the env APP_TOKEN_VALUE.")
    else:
        cust_conn_string = os.environ["AZURE_STORAGE_CONNECTION_STRING"]
       
        encrypted_file_name = "financial_sample.csv.enc"
        decrypted_file_name = encrypted_file_name[:-4]
        key = b'\xbf\xc0\x85)\x10nc\x94\x02)j\xdf\xcb\xc4\x94\x9d(\x9e[EX\xc8\xd5\xbfI{\xa2$\x05(\xd5\x18'

        cust_blob_client = BlobClient.from_connection_string(cust_conn_string,
        container_name="compdev-customer-storage-container", blob_name= encrypted_file_name)

        downloaded_blob = cust_blob_client.download_blob()
        downloaded_blob_data = downloaded_blob.content_as_bytes()
        
        decrypted_data = decrypt(downloaded_blob_data, key)

        conn_string = os.environ["AZURE_INTERNAL_STORAGE_CONNECTION_STRING"]
       
        internal_blob_client = BlobClient.from_connection_string(conn_string,
        container_name="comp-dev-storage-container", blob_name=decrypted_file_name)

  
        internal_blob_client.upload_blob(decrypted_data, blob_type='BlockBlob')

        # Send Message to Queue 
        queue_messages = send_queue_message("file_name = " + decrypted_file_name)

        # Delete file from Customer facing Blob Storage
        cust_container_client = ContainerClient.from_connection_string(conn_str=cust_conn_string, container_name="compdev-customer-storage-container")
        cust_container_client.delete_blob(blob="financial_sample.csv.enc")

        return func.HttpResponse(
            "Messages in the queue:" + queue_messages,
             status_code=200
        ) 


def send_queue_message(message):
    connstr = os.environ['SERVICE_BUS_CONNECTION_STR']
    queue_name = os.environ['SERVICE_BUS_QUEUE_NAME']

    with ServiceBusClient.from_connection_string(connstr) as client:
        with client.get_queue_sender(queue_name) as sender:
            # Sending a single message
            single_message = ServiceBusMessage(message)
            sender.send_messages(single_message)

            # Sending a list of messages
           # messages = [ServiceBusMessage("First message"), ServiceBusMessage("Second message")]
           # sender.send_messages(messages)
    message_list = ""
    with client:
        receiver = client.get_queue_receiver(queue_name=queue_name, max_wait_time=5)
        with receiver:
            for msg in receiver:
                message_list += "\nReceived: " + str(msg)
                receiver.complete_message(msg)
    return message_list

def decrypt(ciphertext, key):
    iv = ciphertext[:AES.block_size]
    cipher = AES.new(key, AES.MODE_CBC, iv)
    plaintext = cipher.decrypt(ciphertext[AES.block_size:])
    return plaintext.rstrip(b"\0")
