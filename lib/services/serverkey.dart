import 'package:googleapis_auth/auth_io.dart';

class Serverkey {
  Future<String> server_token() async {
    final scopes = [
      'https://www.googleapis.com/auth/userinfo.email',
      'https://www.googleapis.com/auth/firebase.database',
      'https://www.googleapis.com/auth/firebase.messaging',
    ];

    final client = await clientViaServiceAccount(
      ServiceAccountCredentials.fromJson({
        "type": "service_account",
        "project_id": "unibustrack-e4164",
        "private_key_id": "65b2775f11ed6e94f845b8fc45d5d9e13ff3b224",
        "private_key":
            "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCn8IkdHXRlcKcx\neGw+j9EjIu5vo7XVoSin018ypBTflHiUlLcmOMVyGTtrsaNy7gIO5A5i/p2+S4bi\n+neHXWWEujmxpKoeqJL8zzKEnnkrPg5sJysQYOtKt3dXYK3ep0P2q6/f4ZBPSZV2\nWgmBrWrHV7fvQWCyqua6LPPGMSnNrSGL6Gx/hmsLeZi6gB3eTuHuECGqqVx1LTVX\nJgLmZPtZxesm3fWw4w312zsQn5ncrRTiDfwBOpSeyLt+cTevI4ppROF8N/PsvJ6I\nkJE4MyDikOJdNWFUlibof9+vrwKRRUTrK8WVbbeYzORdIlH3xQKWPSje0NmQKaa2\nMklmV7EVAgMBAAECggEAAXEAlEXk8lvxq2yHrU/JsT4DAuVKUb+U3D/lsMcUwMiC\n8m+GVOcm1rBdwLJhH0LotJ0DfJkH3JLEYR1aOki0btu0VBCAP0weGtpiah38F0Fs\nmUQKzBSw4E7L0O2tAFy6KhtWIptKhEuy4zWpoDnPUU+w7fZHMLFj0pRBMWHJpJDE\nx5Z0FvoubByPfAAo6L+p3mKF6anz5/bieVf1gqxPITZZ3s2qiJiA9IOFdX5YYdj0\nC0fShrJxblxpqikn7SW5F6FfyJCsGmHAG3olT9OzIzkq67zd8zjPIxFC0vonPiac\n/8lyqLhMqFX/PKChAdYnUmfXMMyXb6QNptzxkelwzwKBgQDf0bsQHZmpOn2nLOks\noM7Ic1oXSpAxry/ASebXvOOIep0L49HDwSluq6Zvu+VsZa2Yb7zg5jkPCLL5mh75\nZ5lo4iCf2kX+jGmnYvvSHRmeG9d4ZVmtnBB2GWIWMQIS6oVA91imrIyuAycRlNPQ\n22yLaPp4l/UhDi7dmBv3VTVV2wKBgQDAFgDoIhX9h7gWnehywtCZzHPp+jbx7BZJ\n8Jrwnsdl5Cyz9MB+RqJjb075vtt1Dp/2T1WEdHMDg38amucGY+qBZUBI8SeVxz7y\nCXn9sjD3F5haT1YKm0bzFXo5WABZU4e9ruZCjz21U9BX2IYxtaUUZAcGdOxz6GJq\n8pSk9oFfzwKBgQCrHdTvoEHPsQlKG7r1xMfzVsWlEvulELPoRlf3ztECkgOpiHbi\nO7bqhs9Lk5L2ydHrvlngdANhrBvxWtSdh4gxONkKfb2PvFg2giXW4Sqpx813nbzv\nT2cCc6ubHcLhJW3VWoXrf/ZaP8zJ00gR4QBeoVcFheACcq5/+oA/G2UYiwKBgQCG\n5a0DWRTKdSrSL1lUZv5qVEw/UGqP4XYRvTiCrW9pXiIKy2L4C5D1dfEnsWKbxYaP\nS03KdKFlIU79FzYRpc/FyZ6o2zsqk7/f6MnUYfTDQr3LBpZtYnkkM7wfU28DTIcy\nrgalTcVPd6oEV1p+xItHU6wfW7PG/rdHVk8PvtJCvwKBgFx96lKD3aoiSbShA+d7\nDa73zwzYIzZFXGAVH5xjaS3DKM78ala8t07S22B51jTTsetRIBxh31XEPHgC+kzt\nc3nqezhyeBO+RZ69HKbzgEWk8tljoTz6Nzv6V98B6EEz4hqymNu3OpryqAGfFC14\nJzo/MjxeM4Lo3++9AERZV4jx\n-----END PRIVATE KEY-----\n",
        "client_email":
            "firebase-adminsdk-fbsvc@unibustrack-e4164.iam.gserviceaccount.com",
        "client_id": "102445188022093697543",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url":
            "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url":
            "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40unibustrack-e4164.iam.gserviceaccount.com",
        "universe_domain": "googleapis.com",
      }),
      scopes,
    );
    final accessServerKey = client.credentials.accessToken.data;
    return accessServerKey;
  }
}
