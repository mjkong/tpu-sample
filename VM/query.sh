#!/bin/bash

cd $HOME

source .env/bin/activate

export KAGGLE_USERNAME=moojekong
export KAGGLE_KEY=2e8eef48f6aa18aea819debac48a5363
export DEBIAN_FRONTEND=noninteractive
export CHKPT_BUCKET=gs://mj-maxtext-chkpt-bucket
export CKPT_ROOT_PATH=$HOME/gemma
export UNSCANNED_CKPT_PATH=`cat $HOME/conversion_checkpoint.log | tail -1 | awk '{print $6}'`
export TOKENIZER_PATH=assets/tokenizer.gemma
export LOAD_PARAMETERS_PATH=${UNSCANNED_CKPT_PATH}
export MAX_PREFILL_PREDICT_LENGTH=1024
export MAX_TARGET_LENGTH=2048
export MODEL_NAME=gemma-7b
export ICI_FSDP_PARALLELISM=1
export ICI_AUTOREGRESSIVE_PARALLELISM=-1
export ICI_TENSOR_PARALLELISM=1
export SCAN_LAYERS=false
export WEIGHT_DTYPE=bfloat16
export PER_DEVICE_BATCH_SIZE=11

python JetStream/jetstream/tools/requester.py --tokenizer maxtext/assets/tokenizer.gemma