# Set variables
$suffix = "001"
$resourceGroup = "video-intelligence-demo"
$location = "eastus2"
$modelFormat = "OpenAI"
$gptmodelName = "gpt-4o"
$gptmodelVersion = "2024-05-13"
$gptdeploymentName = "gpt-4o"
$whispermodelName = "whisper"
$whispermodelVersion = "001"
$whisperdeploymentName = "whisper"
$sku = "standard"
$capacity = 150
$whispercapacity = 3
$openAIResourceName = "videodemoopenai" + $suffix
$openAIKind = "OpenAI"
$openAISku = "s0"
$acrName = "videodemoacr" + $suffix
$planName = "video-analysis-plan" 
$appName = "videowithwhisperapp" + $suffix
$storageAccountName = "videowithaistorageact" + $suffix
$shareName = "video-share"
# create resource group
az group create --name $resourceGroup --location $location

# create openAI resource
az cognitiveservices account create --name $openAIResourceName --resource-group $resourceGroup --location $location --kind $openAIKind --sku $openAISku

# Assign the "Cognitive Services OpenAI User" role to the resource
$openAIResourceId = az cognitiveservices account show --name $openAIResourceName --resource-group $resourceGroup --query id -o tsv
# get the current user
$userId = az ad signed-in-user show --query id -o tsv
az role assignment create --assignee $userId --role "Cognitive Services OpenAI User" --scope $openAIResourceId

# Create GPT 4o model deployment
$gptServiceInfo = az cognitiveservices account deployment create --model-format $modelFormat --model-name $gptmodelName --model-version $gptmodelVersion --name $openAIResourceName --resource-group $resourceGroup --deployment-name $gptdeploymentName --sku $sku --capacity $capacity 

# Create Whisper model
$whisperServiceInfo= az cognitiveservices account deployment create --model-format $modelFormat --model-name $whispermodelName --model-version $whispermodelVersion --name $openAIResourceName --resource-group $resourceGroup --deployment-name $whisperdeploymentName --sku $sku --capacity $whispercapacity

# get the endpoint and key 
$ENDPOINT= az cognitiveservices account show --name $openAIResourceName  --resource-group $resourceGroup --query properties.endpoint -o tsv
$KEY=az cognitiveservices account keys list --name $openAIResourceName --resource-group $resourceGroup --query key1 -o tsv

# create an azure container registry with admin enabled

az acr create --resource-group $resourceGroup --name $acrName --sku Basic --admin-enabled true

# Get the ACR login server
$acrLoginServer = az acr show --name $acrName --resource-group $resourceGroup --query loginServer --output tsv


# Get the ACR admin password
$acrPassword = az acr credential show --name $acrName --resource-group $resourceGroup --query passwords[0].value --output tsv



# Build the Docker image using acr build and tag it
$tag="v1"
az acr build --image video-analysis-with-gpt-4o:$tag --registry $acrName . 

# create an appservice plan with support for linux to host the container

az appservice plan create --name $planName --resource-group $resourceGroup --is-linux --sku P0v3

# create a web app with the container image

az webapp create --resource-group $resourceGroup --plan $planName --name $appName --deployment-container-image-name $acrLoginServer/video-analysis-with-gpt-4o:$tag
# if you want to set the container later..
#az webapp config container set --name $appName --resource-group $resourceGroup --docker-custom-image-name $acrLoginServer/video-analysis-with-gpt-4o:$tag 

# create an azure storage account that we need to mount

az storage account create --name $storageAccountName --resource-group $resourceGroup --location $location --sku Standard_LRS
# create a azure files share
az storage share create --name $shareName --account-name $storageAccountName


#mount the file share to the web app with name temp
$storageKey = az storage account keys list --account-name $storageAccountName --resource-group $resourceGroup --query "[0].value" -o tsv
az webapp config storage-account add --resource-group $resourceGroup --name $appName --custom-id $shareName --storage-type AzureFiles --share-name $shareName --account-name $storageAccountName --access-key $storageKey --mount-path /temp

# Stop the web app
az webapp stop --name $appName --resource-group $resourceGroup

az webapp config appsettings set --resource-group $resourceGroup --name $appName --settings WEBSITES_PORT=8501
az webapp config appsettings set --resource-group $resourceGroup --name $appName --settings AZURE_OPENAI_ENDPOINT=$ENDPOINT
az webapp config appsettings set --resource-group $resourceGroup --name $appName --settings AZURE_OPENAI_API_KEY=$KEY
az webapp config appsettings set --resource-group $resourceGroup --name $appName --settings AZURE_OPENAI_DEPLOYMENT_NAME=$gptdeploymentName
az webapp config appsettings set --resource-group $resourceGroup --name $appName --settings WHISPER_ENDPOINT=$ENDPOINT
az webapp config appsettings set --resource-group $resourceGroup --name $appName --settings WHISPER_API_KEY=$KEY
az webapp config appsettings set --resource-group $resourceGroup --name $appName --settings WHISPER_DEPLOYMENT_NAME=$whisperdeploymentName
az webapp config appsettings list
# stat the web app
az webapp start --name $appName --resource-group $resourceGroup

# browse to appservice
az webapp browse --name $appName --resource-group $resourceGroup

# extra stuff
# if you want to point to another service endpoint (had issue with rps on previous)
$otherOpenAPIEndPoint='PUTINENDPOINTHERE'
$otherOpenAPIKey='PUTINKEYHERE'
$othergptdeploymentName='gpt-4o'
$otherwhisperdeploymentName='whisper'
az webapp stop --name $appName --resource-group $resourceGroup

az webapp config appsettings set --resource-group $resourceGroup --name $appName --settings WEBSITES_PORT=8501
az webapp config appsettings set --resource-group $resourceGroup --name $appName --settings AZURE_OPENAI_ENDPOINT=$otherOpenAPIEndPoint
az webapp config appsettings set --resource-group $resourceGroup --name $appName --settings AZURE_OPENAI_API_KEY=$otherOpenAPIKey
az webapp config appsettings set --resource-group $resourceGroup --name $appName --settings AZURE_OPENAI_DEPLOYMENT_NAME=$othergptdeploymentName
az webapp config appsettings set --resource-group $resourceGroup --name $appName --settings WHISPER_ENDPOINT=$otherOpenAPIEndPoint
az webapp config appsettings set --resource-group $resourceGroup --name $appName --settings WHISPER_API_KEY=$otherOpenAPIKey
az webapp config appsettings set --resource-group $resourceGroup --name $appName --settings WHISPER_DEPLOYMENT_NAME=$otherwhisperdeploymentName
az webapp config appsettings list --resource-group $resourceGroup --name $appName 
az webapp start --name $appName --resource-group $resourceGroup





# rebuild and deploy if required

# change the tag for a new version
$tag="v2"
az acr build --image video-analysis-with-gpt-4o:$tag --registry $acrName .
az webapp stop --name $appName --resource-group $resourceGroup
az webapp config container set --name $appName --resource-group $resourceGroup --docker-custom-image-name $acrLoginServer/video-analysis-with-gpt-4o:$tag 
az webapp start --name $appName --resource-group $resourceGroup

# Clean up resources if needed
az group delete --name $resourceGroup --yes