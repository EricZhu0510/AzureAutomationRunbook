import requests
import json
#change information below to your environment's property
postdata = {
    'grant_type' : 'client_credentials',
    #client id and client secret can be found in your registered application in Azure
    'client_id' : '',
    'client_secret' : '',
    'resource' : 'https://management.azure.com/'
}
def getToken():
    #change tenant id in this url
    url = 'https://login.microsoftonline.com/{your tenent id}/oauth2/token'
    resp = requests.post(url, data=postdata)
    respJson = json.loads(resp.content)
    bearerToken = respJson['access_token']
    return bearerToken
def getMetric(bearerToken):
    header = {'Authorization': 'Bearer '+bearerToken}
    #change resource id in this url
    url = "https://management.azure.com/subscriptions/{Resource ID}/microsoft.insights/metrics?api-version=2018-01-01"
    sess = requests.session()
    resp = sess.get(url, headers=header)
    print(resp.content)
def main():
    bearerToken = getToken()
    getMetric(bearerToken)
if __name__ == '__main__':
    main()
