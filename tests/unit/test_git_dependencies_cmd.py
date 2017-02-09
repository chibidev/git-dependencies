import os

import imp

import pytest
from mock import patch

git_dependencies_path = os.path.join(os.path.dirname(__file__), '..', '..', 'git-dependencies')
git_dependencies_cmd = imp.load_source('git-dependencies', git_dependencies_path)

class GitDependenciesCommandLineTestCase(object):
    @classmethod
    def setup_class(cls):
        parser = git_dependencies_cmd.create_parser()
        cls.parser = parser

    def test_with_empty_args(self, capsys):
        with pytest.raises(SystemExit):
            self.parser.parse_args([])
        out, err = capsys.readouterr()
        assert err.startswith('usage: git dependencies')

    @patch('git.dependencies.GitDependenciesRepository.addDependency')
    def test_add_command(self, mock_method):
        args = self.parser.parse_args(['add',
                                       'https://example.com/sample.git',
                                       'dependencies/example',
                                       'master'])
        git_dependencies_cmd.call_command(args)
        mock_method.assert_called_with(url = 'https://example.com/sample.git',
                                       path = 'dependencies/example',
                                       ref = 'master')

    @patch('git.dependencies.GitDependenciesRepository.removeDependency')
    def test_remove_command(self, mock_method):
        args = self.parser.parse_args(['remove',
                                       'dependencies/example'])
        git_dependencies_cmd.call_command(args)
        mock_method.assert_called_with(path = 'dependencies/example')
