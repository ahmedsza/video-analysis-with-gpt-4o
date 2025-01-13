
## Azure Deployment with PowerShell

This script performs the following actions:

1. Sets variable values for resource names, locations, and model details.  
2. Creates a resource group and an OpenAI cognitive services account.  
3. Assigns the “Cognitive Services OpenAI User” role to the signed-in user.  
4. Deploys GPT and Whisper models under the created OpenAI resource.  
5. Retrieves endpoint and key information for connecting to the OpenAI resource.  
6. Creates an Azure Container Registry (ACR) and uses it to build and store a Docker image.  
7. Creates an App Service plan (Linux) and a Web App, then configures it to pull the container image from ACR.  
8. Provisionally sets up an Azure Storage account and files share, and mounts it to the Web App.  
9. Adds necessary App Settings (port, OpenAI info), then stops and configures the Web App.  
10. Deletes the resource group (and all contained resources) at the end.
