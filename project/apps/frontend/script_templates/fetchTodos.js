async function fetchTodos() {
    const response = await fetch('/{{index .apps.backend.containerNames 0}}');
    const todos = await response.json();
    const todoList = document.getElementById('todoList');
    todos.forEach(todo => {
        const listItem = document.createElement('li');
        listItem.innerHTML = todo;
        todoList.appendChild(listItem);
    });
}
fetchTodos();
