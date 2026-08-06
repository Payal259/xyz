SELECT 
  _cognizanttechnologys.firstName AS firstName,
  _cognizanttechnologys.lastName AS lastName,
  _cognizanttechnologys.emailAddress AS emailAddress,
  _cognizanttechnologys.phoneNumber AS phoneNumber,
  _cognizanttechnologys.accountNumber AS accountNumber,
  _cognizanttechnologys.dateOfBirth AS dateOfBirth
FROM customer_profile_dataset
WHERE _cognizanttechnologys.accountNumber LIKE 'ACC%'