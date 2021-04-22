-- @block lars_to_fix
SELECT
    count(id) lars_to_fix,
    count(distinct account__c) accounts_w_lar_to_fix
FROM data.staging_salesforce.batchaccountrelation__c
WHERE
    NOT isdeleted
    AND assignement_date__c IS NOT NULL
    AND owner_relation__c IS NULL;