-- @block Select account history
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
    and newvalue__string not like '%Reassignment%';

-- @block count_distinct_accounts
SELECT 
    count(distinct accountid)
FROM staging_salesforce.accounthistory
WHERE 
    field = 'Owner' 
    and oldvalue__string <> newvalue__string 
    and oldvalue__string not like '0053X%'
    and newvalue__string <> 'Outbound Database' 
    and newvalue__string not like '%Reassignment%';