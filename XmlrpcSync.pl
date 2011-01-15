package MT::Plugin::OMV::XmlrpcSync;

use strict;
use MT::Entry;
use MT::Template;
use XMLRPC::Lite;

use vars qw( $MYNAME $VERSION );
$MYNAME = 'XmlrpcSync';
$VERSION = '0.11';

use base qw( MT::Plugin );
my $plugin = __PACKAGE__->new({
    name => $MYNAME,
    id => lc $MYNAME,
    key => lc $MYNAME,
    version => $VERSION,
    author_name => 'Open MagicVox.net',
    author_link => 'http://www.magicvox.net/',
    doc_link => 'http://www.magicvox.net/archive/2010/04101503/',
    description => <<PERLHEREDOC,
<__trans phrase="Synchronize the posted entry onto the external blogs with XML-RPC">
PERLHEREDOC
    blog_config_template => 'config.tmpl',
    settings => new MT::PluginSettings([
        [ 'xmlrpc_settings', { Default => undef, scope => 'blog' } ],
    ]),
});
MT->add_plugin ($plugin);

sub instance { $plugin; }



MT->add_callback ('BuildFile', 5, $plugin, \&_entry_post_save);
sub _entry_post_save {
    my ($eh, %opt) = @_;

    my $ctx = $opt{Context};
    my $entry = $ctx->stash ('entry')
        or return 1;
    my $blog = $ctx->stash ('blog');
    my $settings = &instance->get_config_value ('xmlrpc_settings', "blog:". $blog->id)
        or return 1; # no settings

    my $tmpl = MT::Template->load ({ blog_id => $blog->id, name => $MYNAME })
        or return 1;
    my $tmpl_ctx = $tmpl->context;
    $tmpl_ctx->stash ('blog', $blog);
    $tmpl_ctx->stash ('entry', $entry);
    my ($title, $body) = $tmpl->output =~ m/(.+)\s+([\s\S]+)/;

    my $pdata = load_plugindata (key_name ($entry->id)) || {};
    foreach (split /[\r\n]+/, $settings) {
        my ($EndPoint, $blogID, $username, $password) = split /,/;
        if (!$pdata->{$EndPoint} && $entry->status == MT::Entry::RELEASE()) {
            my $result = XMLRPC::Lite
                ->proxy ($EndPoint)
                ->call ('metaWeblog.newPost',
                    $blogID,
                    $username,
                    $password,
                    {
                        'title' => XMLRPC::Data->type ('string', $title),
                        'description' => XMLRPC::Data->type ('string', $body),
                    },
                    1,
                )->result;
            $pdata->{$EndPoint} = $result if defined $result;
        }
    }
    save_plugindata (key_name ($entry->id), $pdata);
    1;
}



########################################################################
sub key_name { 'entry_id:'. $_[0]; }

use MT::PluginData;

sub save_plugindata {
    my ($key, $data_ref) = @_;
    my $pd = MT::PluginData->load({ plugin => &instance->id, key=> $key });
    if (!$pd) {
        $pd = MT::PluginData->new;
        $pd->plugin( &instance->id );
        $pd->key( $key );
    }
    $pd->data( $data_ref );
    $pd->save;
}

sub load_plugindata {
    my ($key) = @_;
    my $pd = MT::PluginData->load({ plugin => &instance->id, key=> $key })
        or return undef;
    $pd->data;
}

1;