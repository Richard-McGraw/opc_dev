#run workflow
Richard-McGraw/opc_dev - set owner and repo
2853768 - workflow id/ action.yaml /workflow name
ref - set branch or tag
inputs specifies variable

curl -L   -X POST   -H "Accept: application/vnd.github+json"   -H "Authorization: Bearer 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"  -H "X-GitHub-Api-Version: 2022-11-28"   https://api.github.com/repos/Richard-McGraw/opc_dev/actions/workflows/62853768/dispatches -d '{"ref":"main", "inputs": { "logLevel":"info", "tags":"true", "environment":"testenv" }}'


#get status od lst workflow run
curl -L   -X GET   -H "Accept: application/vnd.github+json"   -H "Authorization: Bearer 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"  -H "X-GitHub-Api-Version: 2022-11-28"   https://api.github.com/repos/Richard-McGraw/opc_dev/actions/workflows/62853768/runs?per_page=1 |grep -e status -e conclu

#OK
"status": "completed",
"conclusion": "success",
#NotOK
"status": "completed",
"conclusion": "failure",
#runnig
"status": "in_progress",
"conclusion": null,
