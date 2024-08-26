# JetStream을 사용하여 GKE에서 TPU를 사용하여 Gemma 서빙 환경 설정

### 사전 환경 준비
##### 아래의 환경 변수를 테스트를 하기 위한 환경에 맞춰 수정하고 터미널 환경에 적용합니다.

```sh
gcloud config set project PROJECT_ID
export PROJECT_ID=$(gcloud config get project)
export CLUSTER_NAME=<Cluster Name>
export BUCKET_NAME=<Bucket Name>
export REGION=us-west1
export LOCATION=us-west1
export VPC_NAME=projects/<Project ID>/global/networks/<VPC Name>
export SUBNETWORK=projects/<Project ID>/regions/us-west1/subnetworks/<Subnet Name>
export GCE_SERVICE_ACCOUNT=<Service Account for GCE>
```

### GKE 생성

```sh
gcloud beta container clusters create-auto ${CLUSTER_NAME} \
  --region ${REGION} \
  --release-channel "regular" \
  --network ${VPC_NAME} \
  --subnetwork ${SUBNETWORK} \
  --service-account=${GCE_SERVICE_NAME}
```

### Gemma 모델 저장을 위한 버킷 생성
```sh
gcloud storage buckets create gs://${BUCKET_NAME} --location=${REGION}
```

### GKE 접속
```sh
gcloud container clusters get-credentials ${CLUSTER_NAME} --location=${REGION}
```

### Gemma 다운로드를 위한 kaggle credential 설정
```sh
kubectl create secret generic kaggle-secret \
    --from-file=kaggle.json
```

### GKE용 워크로드 아이덴티티 제휴를 사용하여 워크로드 액세스 구성
```sh
# 애플리케이션의 IAM 서비스 계정
gcloud iam service-accounts create wi-jetstream

# IAM 서비스 계정에 IAM 정책 바인딩을 추가하여 Cloud Storage를 관리
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member "serviceAccount:wi-jetstream@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role roles/storage.objectUser

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member "serviceAccount:wi-jetstream@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role roles/storage.insightsCollectorService

# Kubernetes 서비스 계정이 IAM 서비스 계정 역할을 하도록 허용
gcloud iam service-accounts add-iam-policy-binding wi-jetstream@${PROJECT_ID}.iam.gserviceaccount.com \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:${PROJECT_ID}.svc.id.goog[default/default]"

# Kubernetes 서비스 계정에 IAM 서비스 계정의 이메일 주소를 주석으로 추가
kubectl annotate serviceaccount default \
    iam.gke.io/gcp-service-account=wi-jetstream@${PROJECT_ID}.iam.gserviceaccount.com
```

### 모델 체크포인트 변환
```sh
# Gemma 모델 다운로드 및 체크포인트 변환을 위한 job 실행
kubectl apply -f job-7b.yaml

# 로그 확인
kubectl logs -f jobs/data-loader-7b

# 로그에서 아래와 같은 결과를 확인하면 모델 체크포인트 변환 완료
Successfully generated decode checkpoint at: gs://BUCKET_NAME/final/unscanned/gemma_7b-it/0/checkpoints/0/items
+ echo -e '\nCompleted unscanning checkpoint to gs://BUCKET_NAME/final/unscanned/gemma_7b-it/0/checkpoints/0/items'

Completed unscanning checkpoint to gs://BUCKET_NAME/final/unscanned/gemma_7b-it/0/checkpoints/0/items
```

### JetStream 배포
```sh
# JetStream 을 위한 Deployment 배포
kubectl apply -f jetstream-gemma-deployment.yaml
```

### 배포 완료 후 curl을 통한 테스트
```sh
kubectl port-forward svc/jetstream-http-svc 8000:8000

curl --request POST \
--header "Content-type: application/json" \
-s \
localhost:8000/generate \
--data \
'{
    "prompt": "What are the top 5 programming languages",
    "max_tokens": 200
}'
```

### GRadio 채팅 인터페이스를 통해 모델 테스트
```sh
kubectl apply -f gradio.yaml

# 포트포워트 설정 브라우저를 통해 테스트
kubectl port-forward service/gradio 8080:8080
```