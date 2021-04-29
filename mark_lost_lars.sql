-- @block Get LARs to mark as lost (to execute after all lars that could be fixed actually have been)
SELECT
    distinct id
FROM data.staging_salesforce.batchaccountrelation__c
WHERE
    not isdeleted
    and assignement_date__c IS NOT NULL
    and owner_relation__c IS NULL;