SELECT 
  _id,
  person.name.firstName,
  person.name.lastName,
  personalEmail.address
FROM 
  "my_customer_dataset_mp_20260629_190845_480"
LIMIT 10