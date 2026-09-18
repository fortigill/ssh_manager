#!/bin/bash

REGISTRY_FILE="db_registry.txt"
DELETE_PASSWORD="fortinetwins"

# Initialize default databases registry and files if they don't exist
if [ ! -f "$REGISTRY_FILE" ]; then
    echo "Work-Stuff:work_db.txt" > "$REGISTRY_FILE"
    echo "DABLAB:dab_db.txt" >> "$REGISTRY_FILE"
    echo "Public-Hosts:pub_db.txt" >> "$REGISTRY_FILE"
fi

# Ensure default database files exist
while IFS=':' read -r desc fname; do
    [ ! -f "$fname" ] && touch "$fname"
done < "$REGISTRY_FILE"

# Function to select or create a database
choose_db() {
    while true; do
        echo ""
        echo "--- Select Database ---"
        i=1
        while IFS=':' read -r desc fname; do
            echo "  $i) $desc ($fname)"
            i=$((i + 1))
        done < "$REGISTRY_FILE"

        total_dbs=$(wc -l < "$REGISTRY_FILE")
        create_opt=$((total_dbs + 1))
        echo "  $create_opt) Create a new database"
        echo "  q) Cancel / Go back"

        read -p "Choose an option: " db_choice

        if [ "$db_choice" = "q" ] || [ "$db_choice" = "Q" ]; then
            SELECTED_DB_FILE=""
            return 1
        fi

        if ! [[ "$db_choice" =~ ^[0-9]+$ ]]; then
            echo "❌ Invalid input."
            continue
        fi

        if [ "$db_choice" -eq "$create_opt" ]; then
            echo ""
            echo "--- Create New Database ---"
            read -p "Enter a description name (e.g., Home Lab): " new_desc
            read -p "Enter a database filename (e.g., home_db.txt): " new_file

            if [ -z "$new_desc" ] || [ -z "$new_file" ]; then
                echo "❌ Error: Both fields are required."
                continue
            fi

            if [[ ! "$new_file" =~ \.txt$ ]]; then
                new_file="${new_file}.txt"
            fi

            if grep -q ":$new_file" "$REGISTRY_FILE"; then
                echo "❌ A database with that filename already exists."
                continue
            fi

            echo "$new_desc:$new_file" >> "$REGISTRY_FILE"
            [ ! -f "$new_file" ] && touch "$new_file"
            echo "✅ New database '$new_desc' created successfully!"

            SELECTED_DB_FILE="$new_file"
            SELECTED_DB_DESC="$new_desc"
            return 0
        elif [ "$db_choice" -ge 1 ] && [ "$db_choice" -le "$total_dbs" ]; then
            line=$(sed -n "${db_choice}p" "$REGISTRY_FILE")
            SELECTED_DB_DESC=$(echo "$line" | cut -d':' -f1)
            SELECTED_DB_FILE=$(echo "$line" | cut -d':' -f2)
            [ ! -f "$SELECTED_DB_FILE" ] && touch "$SELECTED_DB_FILE"
            return 0
        else
            echo "❌ Invalid option."
        fi
    done
}

add_host() {
    echo ""
    echo "--- Add New Host ---"
    echo "Select which database to add the host into:"
    choose_db || return

    echo ""
    echo "Adding host to: $SELECTED_DB_DESC ($SELECTED_DB_FILE)"
    read -p "Enter a friendly name/alias for the host: " alias
    read -p "Enter the username [default: admin]: " user

    # Default to admin if left blank
    if [ -z "$user" ]; then
        user="admin"
    fi

    read -p "Enter the host IP or FQDN: " host

    if [ -z "$alias" ] || [ -z "$host" ]; then
        echo "❌ Error: Alias and Host IP/FQDN are required."
        return
    fi

    echo "$alias:$user:$host" >> "$SELECTED_DB_FILE"
    echo "✅ Host '$alias' ($user@$host) added successfully to $SELECTED_DB_DESC!"
}

delete_host() {
    echo ""
    echo "--- Delete Host ---"

    read -s -p "Enter the password to delete a host: " entered_pass
    echo ""

    if [ "$entered_pass" != "$DELETE_PASSWORD" ]; then
        echo "❌ Incorrect password. Deletion cancelled."
        return
    fi

    echo "Access granted."
    echo "Select which database to delete a host from:"
    choose_db || return

    if [ ! -s "$SELECTED_DB_FILE" ]; then
        echo "⚠️ No hosts found in '$SELECTED_DB_DESC'."
        return
    fi

    echo ""
    echo "Current Hosts in $SELECTED_DB_DESC:"
    i=1
    while IFS=':' read -r alias user host; do
        echo "  $i) $alias ($user@$host)"
        i=$((i + 1))
    done < "$SELECTED_DB_FILE"

    read -p "Enter the number of the host to delete (or press Enter to cancel): " choice

    if [ -z "$choice" ]; then
        return
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
        echo "❌ Invalid input. Please enter a number."
        return
    fi

    total_lines=$(wc -l < "$SELECTED_DB_FILE")
    if [ "$choice" -ge 1 ] && [ "$choice" -le "$total_lines" ]; then
        sed -i.bak "${choice}d" "$SELECTED_DB_FILE" && rm -f "${SELECTED_DB_FILE}.bak"
        echo "🗑️ Host deleted successfully from $SELECTED_DB_DESC."
    else
        echo "❌ Invalid host number."
    fi
}

connect_host() {
    echo ""
    echo "--- Connect to Host ---"
    echo "Select a database to browse hosts from:"
    choose_db || return

    if [ ! -s "$SELECTED_DB_FILE" ]; then
        echo ""
        echo "⚠️ No hosts available in '$SELECTED_DB_DESC'. Please add a host first."
        return
    fi

    total_lines=$(wc -l < "$SELECTED_DB_FILE")
    local current=1

    while true; do
        echo ""
        local end=$((current + 9))
        if [ $end -gt $total_lines ]; then
            end=$total_lines
        fi

        echo "--- [$SELECTED_DB_DESC] Showing hosts $current to $end of $total_lines ---"

        i=$current
        while [ $i -le $end ]; do
            line=$(sed -n "${i}p" "$SELECTED_DB_FILE")
            alias=$(echo "$line" | cut -d':' -f1)
            user=$(echo "$line" | cut -d':' -f2)
            host=$(echo "$line" | cut -d':' -f3)
            echo "  $i) $alias — $user@$host"
            i=$((i + 1))
        done

        echo ""
        echo -n "Press [Spacebar] for next 10, type host # (then Enter), or 'q' to go back: "

        IFS= read -n 1 -s key

        if [ "$key" = "q" ] || [ "$key" = "Q" ]; then
            echo ""
            return
        elif [ "$key" = " " ]; then
            echo ""
            if [ $total_lines -le 10 ]; then
                echo "ℹ️ All $total_lines hosts are already displayed on this page."
                sleep 1
                continue
            fi
            current=$((current + 10))
            if [ $current -gt $total_lines ]; then
                current=1
                echo "🔄 Reached the end. Wrapping back to page 1..."
                sleep 1
            fi
            continue
        elif [[ "$key" =~ ^[0-9]$ ]]; then
            choice="$key"
            while true; do
                IFS= read -n 1 -s next_char
                if [ -z "$next_char" ] || [ "$next_char" = $'\n' ] || [ "$next_char" = $'\r' ]; then
                    break
                fi
                choice="$choice$next_char"
            done
            echo ""

            if [ "$choice" -ge 1 ] && [ "$choice" -le "$total_lines" ]; then
                line=$(sed -n "${choice}p" "$SELECTED_DB_FILE")
                alias=$(echo "$line" | cut -d':' -f1)
                user=$(echo "$line" | cut -d':' -f2)
                host=$(echo "$line" | cut -d':' -f3)

                echo "🚀 Connecting to $alias ($user@$host)... (Auto abort in 5 seconds on no response...)"
                
                # Protect script from Ctrl+C while letting ssh handle it
                trap '' INT
                ssh -o ConnectTimeout=5 "$user@$host"
                trap - INT

                return
            else
                echo "❌ Invalid host number: $choice"
                sleep 1
            fi
        else
            echo ""
            echo "❌ Invalid input. Press [Spacebar] or enter a host number."
            sleep 1
        fi
    done
}

while true; do
    echo ""
    echo "=============================="
    echo "   SSH Host Manager v1.3a     "
    echo "=============================="
    echo "1) Connect to a Host"
    echo "2) Add a New Host"
    echo "3) Delete a Host"
    echo "4) Exit"
    read -p "Choose an option [1-4]: " option

    case $option in
        1) connect_host ;;
        2) add_host ;;
        3) delete_host ;;
        4) echo "Goodbye!"; exit 0 ;;
        *) echo "❌ Invalid option. Please choose a number between 1 and 4." ;;
    esac
done
