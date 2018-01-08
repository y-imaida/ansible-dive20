# ansible-dive20

DIVERカリキュラム 「DIVE20_1_AWS構築編」「DIVE20_2_AWSデプロイ編」を自動化するためのAnsible Playbookです。

環境構築の作業を以下の2つのPlaybookで実装しています。

1. RailsアプリケーションをデプロイするEC2インスタンスの作成
2. EC2インスタンスの環境構築とRailsアプリケーションのデプロイ

自動化の対象範囲としてデプロイするRailsアプリケーションに対する変更は対象外としているため、カリキュラムの中で行っている以下の作業はPlaybookに含まれていません。（Railsアプリケーションはデプロイできる状態まで準備ができていることを前提としています。）

* 画像をS3へ保存するためのfogに関する設定
* dotenv-rails, Unicorn, Capistranoに関する設定
* gitリポジトリへのコミット など

## 前提

* ansible >= 2.4.2.0(※)
* boto
* boto3

※ EC2のセキュリティグループにIPv6のルールをv2.3.2では設定できないため

## 使い方

### EC2インスタンスの作成

#### 事前準備

##### 環境変数の設定

```
$ export AWS_ACCESS_KEY=XXXXXXXXXX
$ export AWS_SECRET_KEY=XXXXXXXXXX
$ export AWS_REGION=ap-northeast-1
```

##### Playbook実行時に使用する変数の設定

"roles/ec2/vars/main.yml"の変数を環境に合わせて設定する

```
ec2_instance_type: t2.micro
ec2_key_name: <your ec2 key name>  ←EC2インスタンスに設定するキーペアの名前
ec2_group: <your ec2 security group>  ←EC2インスタンスに割り当てるセキュリティグループ名
ec2_group_desc: <your ec2 security group description>  ←セキュリティグループの説明
ec2_name: <your ec2 instance name>  ←EC2インスタンスの"Name"タグに設定する名前
ec2_eip: <your elastic ip address>  ←EC2インスタンスに設定するElastic IP（新規取得する場合はコメントアウト）
```

#### Playbookの実行

```
$ ansible-playbook ec2.yml
```

冪等性の担保をきちんと実装することができていないため、Playbookの実行が途中でエラーとなってしまった場合、そのまま再実行すると不要なEC2インスタンスやElastic IPが残ってしまう可能性があります。エラーとなってしまった場合はAWSコンソールへログインしてPlaybookの実行により作成されたEC2インスタンスとElastic IPを削除してから再実行してください。

#### SSH秘密鍵の確認と配置

Playbookを実行したディレクトリ直下に"*ec2_key_name*.pem"ファイルが作成されていることを確認する。（*ec2_key_name* は"roles/ec2/vars/main.yml"の"ec2_key_name"に設定した値）

また、取得したSSH秘密鍵を環境に合わせて適切な場所へ配置する（ここでは~/.sshディレクトリへ配置する）

```
$ ls *.pem
ec2_key_name.pem

$ mv ec2_key_name.pem ~/.ssh
$ chmod 600 ~/.ssh/ec2_key_name.pem
```

ec2_key_nameに既存のキーペアを指定している場合はSSH秘密鍵は取得されないため、そのキーペアを作成した時にダウンロードした秘密鍵を利用する。

#### Elastic IPの確認

（"roles/ec2/vars/main.yml"の"ec2_eip"に既存のElastic IPを指定した場合は確認しなくてよい）

新規取得したElastic IPをPlaybook実行時のコンソール出力から確認する。

EC2インスタンスに割り当てたElastic IPとRailsアプリケーションの"config/deploy/production.rb"などに設定するアドレスが一致していないとPlaybookが正常に動作しないので注意する。

```
＜・・・省略・・・＞
TASK [ec2 : output EIP address] *****************************************************************************************************************************************************
ok: [localhost] => {
    "eip": {
        "changed": true,
        "msg": "All items completed",
        "results": [
            {
                ＜・・・省略・・・＞
                "item": "i-xxxxxxxxxxxxxxxxx",
                "public_ip": "XXX.XXX.XXX.XXX"  ←新規取得したElastic IPのアドレス
            }
        ]
    }
}
＜・・・省略・・・＞
```

### EC2インスタンスの環境構築とRailsアプリケーションのデプロイ

#### 事前準備

##### Playbook実行時に使用する変数の設定

"inventories/production/hosts"の変数を環境に合わせて設定する

```
all:
  hosts:
    target_for_ec2-user:
      ansible_ssh_user: ec2-user
      ansible_ssh_private_key_file: ~/.ssh/<ec2_key_name>.pem  ←EC2インスタンス作成時に取得したSSH秘密鍵のパス
    target_for_app:
      ansible_ssh_user: app
      ansible_ssh_private_key_file: ~/.ssh/id_rsa
      psql_role: achieve
      psql_db: achieve_production
      github_access_token: <your github access token>  ←GitHub接続用の公開鍵を登録するために必要なトークン取得方法は下記参照（※）
      github_access_key: <your github access key>  ←GitHub接続用の公開鍵の名前
      rails_app: achieve
      facebook_id: <your facebook id> ←FACEBOOK_ID_PRODUCTION環境変数に設定する値
      facebook_secret: <your facebook secret>  ←FACEBOOK_SECRET_PRODUCTION環境変数に設定する値
      pusher_app_id: <your pusher app id>  ←PUSHER_APP_ID環境変数に設定する値
      pusher_key: <your pusher key>  ←PUSHER_KEY環境変数に設定する値
      pusher_secret: <your pusher secret>  ←PUSHER_SECRET環境変数に設定する値
      sendgrid_password: <your sendgrid password>  ←SENDGRID_PASSWORD環境変数に設定する値
      sendgrid_username: <your sendgrid username>  ←SENDGRID_USERNAME環境変数に設定する値
      twitter_id: <your twitter id>  ←TWITTER_ID_PRODUCTION環境変数に設定する値
      twitter_secret: <your twitter secret>  ←TWITTER_SECRET_PRODUCTION環境変数に設定する値
      aws_access_key_id: <your aws access key id>  ←AWS_ACCESS_KEY_ID環境変数に設定する値
      aws_secret_access_key: <your secret access key>  ←AWS_SECRET_ACCESS_KEY環境変数に設定する値
    localhost:
      ansible_python_interpreter: /usr/local/opt/python/bin/python2
      s3_bucket: <your s3 bucket>  ←S3バケットの名前
  vars:
    ansible_host: <your target host>  ←EC2インスタンスに割り当てたElastic IPのアドレス
    ansible_ssh_port: 22
    ec2_name: <your target ec2 instance name>  ←EC2インスタンスのNameタグに設定した値
    rails_app_local_repo: <your rails application local repository path>  ←デプロイするRailsアプリケーションのローカルリポジトリへのパス
```

※GitHub接続用の公開鍵を登録するために必要なトークン取得方法

1. GitHubへログイン
2. "Settings" → "Developer settings" → "Personal access tokens"
3. "Token description"フィールドに任意のトークン名を入力する
4. "Generate new token"ボタンを押す
5. "admin:public_key"-"write:public_key"チェックボックスをクリックする
6. "Generate token"ボタンを押す
7. 画面に表示されるトークンを確認する

#### Playbookの実行

```
$ ansible-playbook -i inventories/production/hosts site.yml
```

以上
