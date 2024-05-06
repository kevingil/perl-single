use strict;
use warnings;
use Mojolicious::Lite;
use DBI;

# Set up the SQLite database file path
my $db_file = './data/app.db';

# Try to connect to the SQLite database
my $dbh;
eval {
    $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", '', '', { RaiseError => 1, AutoCommit => 1 });
};

# If the connection failed, handle the error
if ($@) {
    warn "Failed to connect to database: $@";

    # Try to create the database directory if needed
    my $db_dir = './data';
    if (!-d $db_dir) {
        mkdir $db_dir or die "Could not create directory $db_dir: $!";
    }

    # Re-attempt to connect
    $dbh = DBI->connect("dbi:SQLite:dbname=$db_file", '', '', { RaiseError => 1, AutoCommit => 1 });

    if (!$dbh) {
        die "Failed to connect to SQLite database after handling error";
    }
}

# Now that you have a connection, create the tasks table if it doesn't exist
$dbh->do(<<'SQL');
CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    description TEXT NOT NULL,
    completed INTEGER NOT NULL DEFAULT 0
)
SQL

# Render a basic HTML layout
get '/' => sub {
  my $c = shift;
  
  # Render the layout with a dynamic component
  $c->render(
    inline => layout(),
    component => homepage(),
    format  => 'html'
  );
};

# Function that returns the main layout
sub layout {
  return <<'HTML';
<!DOCTYPE html>
<html lang="en">
<head>
  <title>App</title>
  <script src="https://unpkg.com/htmx.org@1.9.5/dist/htmx.min.js"></script>
  <script src="https://cdn.tailwindcss.com"></script>
</head>
<body>
    <div>
    <h1 class="text-3xl font-bold">
        Test App
    </h1>  
    <div id="content">
        <%== $component %> <!-- This is where dynamic content will be inserted -->
    </div>
    </div>
</body>
</html>
HTML
}



# Function to render the homepage partial
sub homepage {
    my $tasks;
    
    # Fetch tasks from the database
    $tasks = $dbh->selectall_arrayref('SELECT * FROM tasks', { Slice => {} });

    my $html = '<form hx-post="/add" hx-target="#content" hx-swap="innerHTML" method="post">
        <input type="text" name="description" placeholder="New task" required>
        <button type="submit">Add</button>
    </form>';

    $html .= '<ul>';
    foreach my $task (@$tasks) {
        $html .= '<li>';
        $html .= sprintf('<input type="checkbox" hx-post="/toggle/%d" hx-target="#content" hx-swap="innerHTML" %s>',
            $task->{id}, $task->{completed} ? 'checked' : '');
        $html .= sprintf('<span>%s</span>', $task->{description});
        $html .= sprintf('<button hx-post="/delete/%d" hx-target="#content" hx-swap="innerHTML">Delete</button>',
            $task->{id});
        $html .= '</li>';
    }
    $html .= '</ul>';

    return $html;
}

#CRUD ACTIONS
#they operate on DB
#then re render the homepage partial

# Add a new task
post '/add' => sub {
  my $c = shift;
  my $description = $c->param('description');
  $dbh->do('INSERT INTO tasks (description) VALUES (?)', undef, $description);
  # After adding, re-render the list
  $c->render(inline => homepage());
};

# Delete a task
post '/delete/:id' => sub {
  my $c = shift;
  my $id = $c->param('id');
  $dbh->do('DELETE FROM tasks WHERE id = ?', undef, $id);
  # Re-render the list after deleting
  $c->render(inline => homepage());
};

# Toggle task completion
post '/toggle/:id' => sub {
  my $c = shift;
  my $id = $c->param('id');
  my $task = $dbh->selectrow_hashref('SELECT * FROM tasks WHERE id = ?', undef, $id);
  my $completed = !$task->{completed};
  $dbh->do('UPDATE tasks SET completed = ? WHERE id = ?', undef, $completed, $id);
  # Re-render the list after toggling completion
  $c->render(inline => homepage());
};




app->start;
