#!/bin/bash
# Set the current date in Unix timestamp format
current_date=$(date +%s)

# Set the threshold date 90 days ago in Unix timestamp format
threshold_date=$((current_date - (90 * 24 * 3600)))

# Get a list of IAM users from AWS
users_json=$(aws iam list-users --output json)

# Loop through each user
for user_info in $(echo "${users_json}" | jq -c '.Users[]'); do
    user_name=$(echo "${user_info}" | jq -r '.UserName')
    password_last_used=$(echo "${user_info}" | jq -r '.PasswordLastUsed')

    # Check if the user has a password last used date
    if [ "$password_last_used" != "null" ]; then
        # Convert password last used date to Unix timestamp
        password_last_used_timestamp=$(date -d "$password_last_used" +%s)

        # Check if the user hasn't signed in within the last 90 days
        if [ "$password_last_used_timestamp" -lt "$threshold_date" ]; then
            #echo "Checking login profile for user: $user_name"
            login_profile=$(aws iam get-login-profile --user-name "$user_name" 2>/dev/null)

            if [ -n "$login_profile" ]; then
                #echo "Login profile found for user: $user_name. Deleting..."
                # Delete the login profile for the user
                aws iam delete-login-profile --user-name "$user_name"
                echo "Login profile deleted for user: $user_name"
            else
                echo "Login profile not found for user: $user_name"
            fi
        fi
    fi
done

# Get current date
current_date=$(date +%s)

# Calculate date 3 months ago
three_months_ago=$(date -d "3 months ago" +%s)

# Get all users
users=$(aws iam list-users --query "Users[*].UserName" --output text)

# For each user
for user in $users
do
  #echo "Checking user $user"
  
  # Get their access keys
  keys=$(aws iam list-access-keys --user-name $user --query "AccessKeyMetadata[*].AccessKeyId" --output text)
  
  # For each access key
  for key in $keys
  do
    #echo "Checking access key $key of user $user"
    
    # Get the last used date for the key
    last_used_date=$(aws iam get-access-key-last-used --access-key-id $key | jq -r ".AccessKeyLastUsed.LastUsedDate")
    
    # If last used date is empty, assume the key as not used
    if [ "$last_used_date" == "null" ]
    then
      echo -e "$user\t$key"
      #echo $user
      #echo $key
      #echo "Key $key of user $user has never been used. Deactivating..."
      aws iam update-access-key --user-name $user --access-key-id $key --status Inactive
      continue
    fi
    
    # Convert last used date to Unix timestamp
    last_used_date_unix=$(date -d"$last_used_date" +%s)
    
    # Check if key was used in the last 3 months
    if (( last_used_date_unix < three_months_ago ))
    then
      echo -e "$user\t$key"
      #echo $user
      #echo $key
      #echo "Key $key of user $user has not been used for 3 months. Deactivating..."
      aws iam update-access-key --user-name $user --access-key-id $key --status Inactive
    fi
  done
done
