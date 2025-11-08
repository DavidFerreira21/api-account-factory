{
  "Comment": "Account Factory Workflow sem retry, com tratamento de erros",
  "StartAt": "Validate",
  "States": {
    "Validate": {
      "Type": "Task",
      "Resource": "${validate_lambda}",
      "ResultPath": "$",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.Error",
          "Next": "UpdateStatusFailed"
        }
      ],
      "Next": "ProvisionAccount"
    },
    "ProvisionAccount": {
      "Type": "Task",
      "Resource": "${provision_lambda}",
      "ResultPath": "$",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.Error",
          "Next": "UpdateStatusFailed"
        }
      ],
      "Next": "CheckAccountStatus"
    },
    "CheckAccountStatus": {
      "Type": "Task",
      "Resource": "${check_status_lambda}",
      "ResultPath": "$",
      "Catch": [
        {
          "ErrorEquals": ["States.ALL"],
          "ResultPath": "$.Error",
          "Next": "UpdateStatusFailed"
        }
      ],
      "Next": "StatusDecision"
    },
    "StatusDecision": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.Status",
          "StringEquals": "IN_PROCESSING",
          "Next": "Wait5Minutes"
        },
        {
          "Variable": "$.Status",
          "StringEquals": "AVAILABLE",
          "Next": "UpdateStatusSuccess"
        },
        {
          "Variable": "$.Status",
          "StringEquals": "TAINTED",
          "Next": "UpdateStatusSuccess"
        }
      ],
      "Default": "Failed"
    },
    "Wait5Minutes": {
      "Type": "Wait",
      "Seconds": 300,
      "Next": "CheckAccountStatus"
    },
    "UpdateStatusSuccess": {
      "Type": "Task",
      "Resource": "${update_status_lambda}",
      "ResultPath": "$",
      "Next": "FinalDecision"
    },
    "UpdateStatusFailed": {
      "Type": "Task",
      "Resource": "${update_failed_status_lambda}",
      "ResultPath": "$",
      "Next": "FinalDecision"
    },
    "FinalDecision": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.success",
          "StringEquals": "True",
          "Next": "Success"
        }
      ],
      "Default": "Failed"
    },



    "Failed": {
      "Type": "Fail"
    },
    "Success": {
      "Type": "Succeed"
    }
  }
}
