#! /bin/bash

PSQL="psql -X -A --username=freecodecamp --dbname=salon --tuples-only -c"

SERVICE_MENU() {
  # Display any message passed to the function (e.g., from a recursive call)
  if [[ -n "$1" ]]; then
    echo -e "\n$1" # Print the message
  fi

  # Get available services
  AVAILABLE_SERVICES=$($PSQL "SELECT service_id, name FROM services WHERE available = true ORDER BY service_id")

  # If no services available
  if [[ -z "$AVAILABLE_SERVICES" ]]; then
    if [[ -z "$1" ]]; then # Only show this if no other message is already being shown
        echo "Sorry, we don't have any services available right now."
    fi
    return # Exit if no services
  else
    # Display available services
    echo -e "\nHere are the services we offer:\n"
    echo "$AVAILABLE_SERVICES" | while IFS="|" read -r SERVICE_ID SERVICE_NAME; do
      TRIMMED_SERVICE_NAME=$(echo "$SERVICE_NAME" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
      echo "$SERVICE_ID) $TRIMMED_SERVICE_NAME"
    done

    echo -e "\nWhich service would you like to book? (Enter ID)"
    read SERVICE_ID_SELECTED # Requirement: SERVICE_ID_SELECTED

    # Validate service ID selection
    if [[ ! $SERVICE_ID_SELECTED =~ ^[0-9]+$ ]]; then
      SERVICE_MENU "That is not a valid service number. Please enter a numeric ID."
    else
      # Get service availability (and name for later use)
      SELECTED_SERVICE_INFO=$($PSQL "SELECT name, available FROM services WHERE service_id = $SERVICE_ID_SELECTED")

      if [[ -z "$SELECTED_SERVICE_INFO" ]]; then
        SERVICE_MENU "That service ID does not exist. Please choose from the list."
      else
        # Parse service name and availability
        SELECTED_SERVICE_NAME_PARSED=$(echo "$SELECTED_SERVICE_INFO" | cut -d'|' -f1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        IS_SERVICE_AVAILABLE=$(echo "$SELECTED_SERVICE_INFO" | cut -d'|' -f2)

        if [[ "$IS_SERVICE_AVAILABLE" != "t" ]]; then
          SERVICE_MENU "Our apologies, but the selected service '$SELECTED_SERVICE_NAME_PARSED' is currently not available."
        else
          # Service is valid and available, proceed to get customer info
          echo -e "\nWhat's your phone number?"
          read CUSTOMER_PHONE # Requirement: CUSTOMER_PHONE

          # Fetch existing customer name using CUSTOMER_PHONE
          DB_CUSTOMER_NAME_OUTPUT=$($PSQL "SELECT name FROM customers WHERE phone = '$CUSTOMER_PHONE'")
          TRIMMED_DB_CUSTOMER_NAME=$(echo "$DB_CUSTOMER_NAME_OUTPUT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

          # This variable will hold the name to be used in subsequent logic and messages.
          FINAL_CUSTOMER_NAME_FOR_APPOINTMENT=""

          if [[ -z "$TRIMMED_DB_CUSTOMER_NAME" ]]; then
            echo -e "\nIt looks like you're a new customer. What's your name?"
            read CUSTOMER_NAME # Requirement: CUSTOMER_NAME (for new customer name input)
            TRIMMED_NEW_CUSTOMER_NAME_INPUT=$(echo "$CUSTOMER_NAME" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

            # Insert new customer
            INSERT_CUSTOMER_RESULT=$($PSQL "INSERT INTO customers(name, phone) VALUES('$TRIMMED_NEW_CUSTOMER_NAME_INPUT', '$CUSTOMER_PHONE')")
            FINAL_CUSTOMER_NAME_FOR_APPOINTMENT="$TRIMMED_NEW_CUSTOMER_NAME_INPUT"
          else
            FINAL_CUSTOMER_NAME_FOR_APPOINTMENT="$TRIMMED_DB_CUSTOMER_NAME"
          fi

          # Get customer_id (using CUSTOMER_PHONE)
          CUSTOMER_ID_OUTPUT=$($PSQL "SELECT customer_id FROM customers WHERE phone='$CUSTOMER_PHONE'")
          TRIMMED_CUSTOMER_ID=$(echo "$CUSTOMER_ID_OUTPUT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

          # Proceed to book appointment
          echo -e "\nWhat time would you like your $SELECTED_SERVICE_NAME_PARSED, $FINAL_CUSTOMER_NAME_FOR_APPOINTMENT?"
          read SERVICE_TIME # Requirement: SERVICE_TIME

          # Insert the appointment
          INSERT_APPOINTMENT_RESULT=$($PSQL "INSERT INTO appointments(customer_id, service_id, time) VALUES($TRIMMED_CUSTOMER_ID, $SERVICE_ID_SELECTED, '$SERVICE_TIME')")

          if [[ "$INSERT_APPOINTMENT_RESULT" == "INSERT 0 1" ]]; then
            echo -e "\nI have put you down for a $SELECTED_SERVICE_NAME_PARSED at $SERVICE_TIME, $FINAL_CUSTOMER_NAME_FOR_APPOINTMENT."
          else
            SERVICE_MENU "Apologies, we could not schedule your appointment due to an unexpected error. Please try again."
          fi
        fi
      fi
    fi
  fi
}

# Initial call to the service menu
SERVICE_MENU