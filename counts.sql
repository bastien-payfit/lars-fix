-- @block counts
SELECT
    count(distinct id) as total_nb_lars,
    SUM(case when assignement_date__c is not null then 1 else 0 end) as nb_lars_not_in_backlog,
    SUM(case when assignement_date__c is not null and owner_relation__c is null then 1 else 0 end) as nb_lars_to_fix
FROM data.staging_salesforce.batchaccountrelation__c
WHERE
    NOT isdeleted;