-- @block Nb lars to fix after join
WITH lars_to_fix AS (
    SELECT
        id,
        account__c,
        assignement_date__c,
        end_relation_date__c,
        owner_relation__c
    FROM data.staging_salesforce.batchaccountrelation__c
    WHERE
        NOT isdeleted
        AND assignement_date__c IS NOT NULL
        AND owner_relation__c IS NULL
),
history AS (
    SELECT 
        accountid, 
        createddate, 
        oldvalue__string, 
        newvalue__string 
    FROM staging_salesforce.accounthistory
    WHERE 
        field = 'Owner' 
        and oldvalue__string <> newvalue__string 
        and oldvalue__string not like '0053X%'
        and newvalue__string <> 'Outbound Database' 
        and newvalue__string not like '%Reassignment%'
)
SELECT 
    count(*) tot_nb_lines,
    count(distinct lars_to_fix.id) nb_lars_to_fix
FROM lars_to_fix
JOIN history 
    on lars_to_fix.account__c = history.accountid;

-- @block How many LARs associated to accounts with no history
WITH lars_to_fix AS (
    SELECT
        id,
        account__c,
        assignement_date__c,
        end_relation_date__c,
        owner_relation__c
    FROM data.staging_salesforce.batchaccountrelation__c
    WHERE
        NOT isdeleted
        AND assignement_date__c IS NOT NULL
        AND owner_relation__c IS NULL
),
history AS (
    SELECT 
        accountid, 
        createddate, 
        oldvalue__string, 
        newvalue__string 
    FROM staging_salesforce.accounthistory
    WHERE 
        field = 'Owner' 
        and oldvalue__string <> newvalue__string 
        and oldvalue__string not like '0053X%'
        and newvalue__string <> 'Outbound Database' 
        and newvalue__string not like '%Reassignment%'
)
SELECT 
    count(distinct lars_to_fix.id) nb_lars_w_no_history
FROM lars_to_fix
LEFT JOIN history 
    on lars_to_fix.account__c = history.accountid
WHERE history.accountid is null;

-- @block Is lar owner account first owner when no account history?
WITH lars_w_owner AS (
    SELECT
        id,
        account__c,
        assignement_date__c,
        end_relation_date__c,
        owner_relation__c
    FROM data.staging_salesforce.batchaccountrelation__c
    WHERE
        NOT isdeleted
        AND owner_relation__c IS NOT NULL
),
history1 AS (
    SELECT 
        accountid, 
        createddate, 
        oldvalue__string, 
        newvalue__string 
    FROM staging_salesforce.accounthistory
    WHERE 
        field = 'Owner' 
        and oldvalue__string <> newvalue__string
        and oldvalue__string not like '0053X%'
        and newvalue__string <> 'Outbound Database' 
        and newvalue__string not like '%Reassignment%'
),
lars_w_owner_no_history AS (
    SELECT 
        lars_w_owner.id,
        lars_w_owner.account__c,
        lars_w_owner.owner_relation__c
    FROM lars_w_owner
    LEFT JOIN history1 
        on lars_w_owner.account__c = history1.accountid
    WHERE history1.accountid is null
),
history2 AS (
    SELECT 
        accountid, 
        createddate, 
        oldvalue__string, 
        newvalue__string 
    FROM staging_salesforce.accounthistory
    WHERE 
        field = 'Owner' 
        and oldvalue__string not like '0053X%'
        and oldvalue__string <> 'Outbound Database' 
        and oldvalue__string not like '%Reassignment%'
)
SELECT
    lars_w_owner_no_history.*,
    history2.* 
FROM lars_w_owner_no_history
JOIN history2 
ON lars_w_owner_no_history.account__c = history2.accountid
;